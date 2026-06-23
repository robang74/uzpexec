/*
 * (C) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>
 *
 * Copyright (c) 2019-2020, Anton Batenev, BSD 2-clauses
 * https://github.com/abbat/elfexec/blob/master/elfexec.c
 * 
 * Copyright (c) 2007-2017, Andrew Church <achurch@achurch.org>, Public Domain
 * https://achurch.org/tinflate.c
 *
 ***************************************************************************** */

#ifndef __linux__
    #error "Questo programma puo essere eseguito solo su Linux."
#endif

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <assert.h>
#include <limits.h>

#define EE_MEMFD_NAME "upkg"

/* --- Costanti e Configurazione --- */
#define TINF_OK           0
#define TINF_DATA_ERROR  (-1)
#define TINF_BUF_ERROR   (-2)

#ifndef SYS_memfd_create
    #error "memfd_create richiede Linux 3.17 o superiore."
#endif

#define SKIP_SIZE 4096
#define CHUNK_SIZE 8192
#define INITIAL_CAPACITY (256 * 1024)
#define MAX_DECOMPRESSED_SIZE (32 * 1024 * 1024) // Limite di sicurezza a 32MB

extern char **environ;

/* --- Strutture Interne tinflate --- */
struct tinf_tree {
    unsigned short counts[16];
    unsigned short symbols[288];
    int max_sym;
};

struct tinf_data {
    const unsigned char *source;
    const unsigned char *source_end;
    unsigned int tag;
    int bitcount;
    int overflow;

    unsigned char *dest_start;
    unsigned char *dest;
    unsigned char *dest_end;

    struct tinf_tree ltree;
    struct tinf_tree dtree;
};

/* --- Funzioni di Servizio tinflate --- */
static unsigned int read_le16(const unsigned char *p) {
    return ((unsigned int) p[0]) | ((unsigned int) p[1] << 8);
}

static void tinf_build_fixed_trees(struct tinf_tree *lt, struct tinf_tree *dt) {
    int i;
    for (i = 0; i < 16; ++i) lt->counts[i] = 0;
    lt->counts[7] = 24; lt->counts[8] = 152; lt->counts[9] = 112;

    for (i = 0; i < 24; ++i) lt->symbols[i] = 256 + i;
    for (i = 0; i < 144; ++i) lt->symbols[24 + i] = i;
    for (i = 0; i < 8; ++i) lt->symbols[24 + 144 + i] = 280 + i;
    for (i = 0; i < 112; ++i) lt->symbols[24 + 144 + 8 + i] = 144 + i;
    lt->max_sym = 285;

    for (i = 0; i < 16; ++i) dt->counts[i] = 0;
    dt->counts[5] = 32;
    for (i = 0; i < 32; ++i) dt->symbols[i] = i;
    dt->max_sym = 29;
}

static int tinf_build_tree(struct tinf_tree *t, const unsigned char *lengths, unsigned int num) {
    unsigned short offs[16];
    unsigned int i, num_codes, available;

    assert(num <= 288);
    for (i = 0; i < 16; ++i) t->counts[i] = 0;
    t->max_sym = -1;

    for (i = 0; i < num; ++i) {
        assert(lengths[i] <= 15);
        if (lengths[i]) {
            t->max_sym = i;
            t->counts[lengths[i]]++;
        }
    }

    for (available = 1, num_codes = 0, i = 0; i < 16; ++i) {
        unsigned int used = t->counts[i];
        if (used > available) return TINF_DATA_ERROR;
        available = 2 * (available - used);
        offs[i] = num_codes;
        num_codes += used;
    }

    if ((num_codes > 1 && available > 0) || (num_codes == 1 && t->counts[1] != 1)) {
        return TINF_DATA_ERROR;
    }

    for (i = 0; i < num; ++i) {
        if (lengths[i]) t->symbols[offs[lengths[i]]++] = i;
    }

    if (num_codes == 1) {
        t->counts[1] = 2;
        t->symbols[1] = t->max_sym + 1;
    }

    return TINF_OK;
}

static void tinf_refill(struct tinf_data *d, int num) {
    assert(num >= 0 && num <= 32);
    while (d->bitcount < num) {
        if (d->source != d->source_end) {
            d->tag |= (unsigned int) *d->source++ << d->bitcount;
        } else {
            d->overflow = 1;
        }
        d->bitcount += 8;
    }
    assert(d->bitcount <= 32);
}

static unsigned int tinf_getbits_no_refill(struct tinf_data *d, int num) {
    unsigned int bits;
    assert(num >= 0 && num <= d->bitcount);
    bits = d->tag & ((1UL << num) - 1);
    d->tag >>= num;
    d->bitcount -= num;
    return bits;
}

static unsigned int tinf_getbits(struct tinf_data *d, int num) {
    tinf_refill(d, num);
    return tinf_getbits_no_refill(d, num);
}

static unsigned int tinf_getbits_base(struct tinf_data *d, int num, int base) {
    return base + (num ? tinf_getbits(d, num) : 0);
}

static int tinf_decode_symbol(struct tinf_data *d, const struct tinf_tree *t) {
    int base = 0, offs = 0, len;
    for (len = 1; ; ++len) {
        offs = 2 * offs + tinf_getbits(d, 1);
        assert(len <= 15);
        if (offs < t->counts[len]) break;
        base += t->counts[len];
        offs -= t->counts[len];
    }
    assert(base + offs >= 0 && base + offs < 288);
    return t->symbols[base + offs];
}

static int tinf_decode_trees(struct tinf_data *d, struct tinf_tree *lt, struct tinf_tree *dt) {
    unsigned char lengths[288 + 32];
    static const unsigned char clcidx[19] = {
        16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
    };
    unsigned int hlit, hdist, hclen, i, num, length;
    int res;

    hlit = tinf_getbits_base(d, 5, 257);
    hdist = tinf_getbits_base(d, 5, 1);
    hclen = tinf_getbits_base(d, 4, 4);

    if (hlit > 286 || hdist > 30) return TINF_DATA_ERROR;

    for (i = 0; i < 19; ++i) lengths[i] = 0;
    for (i = 0; i < hclen; ++i) {
        lengths[clcidx[i]] = tinf_getbits(d, 3);
    }

    res = tinf_build_tree(lt, lengths, 19);
    if (res != TINF_OK) return res;
    if (lt->max_sym == -1) return TINF_DATA_ERROR;

    for (num = 0; num < hlit + hdist; ) {
        int sym = tinf_decode_symbol(d, lt);
        if (sym > lt->max_sym) return TINF_DATA_ERROR;

        switch (sym) {
        case 16:
            if (num == 0) return TINF_DATA_ERROR;
            sym = lengths[num - 1];
            length = tinf_getbits_base(d, 2, 3);
            break;
        case 17:
            sym = 0;
            length = tinf_getbits_base(d, 3, 3);
            break;
        case 18:
            sym = 0;
            length = tinf_getbits_base(d, 7, 11);
            break;
        default:
            length = 1;
            break;
        }

        if (length > hlit + hdist - num) return TINF_DATA_ERROR;
        while (length--) lengths[num++] = sym;
    }

    if (lengths[256] == 0) return TINF_DATA_ERROR;

    res = tinf_build_tree(lt, lengths, hlit);
    if (res != TINF_OK) return res;

    res = tinf_build_tree(dt, lengths + hlit, hdist);
    if (res != TINF_OK) return res;

    return TINF_OK;
}

static int tinf_inflate_block_data(struct tinf_data *d, struct tinf_tree *lt, struct tinf_tree *dt) {
    static const unsigned char length_bits[30] = {
        0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0, 127
    };
    static const unsigned short length_base[30] = {
         3,  4,  5,   6,   7,   8,   9,  10,  11,  13, 15, 17, 19,  23,  27,  31,  35,  43,  51,  59, 67, 83, 99, 115, 131, 163, 195, 227, 258,   0
    };
    static const unsigned char dist_bits[30] = {
        0, 0,  0,  0,  1,  1,  2,  2,  3,  3, 4, 4,  5,  5,  6,  6,  7,  7,  8,  8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
    };
    static const unsigned short dist_base[30] = {
           1,    2,    3,    4,    5,    7,    9,    13,    17,    25,   33,   49,   65,   97,  129,  193,  257,   385,   513,   769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577
    };

    for (;;) {
        int sym = tinf_decode_symbol(d, lt);
        if (d->overflow) return TINF_DATA_ERROR;

        if (sym < 256) {
            if (d->dest == d->dest_end) return TINF_BUF_ERROR;
            *d->dest++ = sym;
        } else {
            int length, dist, offs, i;
            if (sym == 256) return TINF_OK;
            if (sym > lt->max_sym || sym - 257 > 28 || dt->max_sym == -1) return TINF_DATA_ERROR;

            sym -= 257;
            length = tinf_getbits_base(d, length_bits[sym], length_base[sym]);
            dist = tinf_decode_symbol(d, dt);

            if (dist > dt->max_sym || dist > 29) return TINF_DATA_ERROR;
            offs = tinf_getbits_base(d, dist_bits[dist], dist_base[dist]);

            if (offs > d->dest - d->dest_start) return TINF_DATA_ERROR;
            if (d->dest_end - d->dest < length) return TINF_BUF_ERROR;

            for (i = 0; i < length; ++i) d->dest[i] = d->dest[i - offs];
            d->dest += length;
        }
    }
}

static int tinf_inflate_uncompressed_block(struct tinf_data *d) {
    unsigned int length, invlength;
    if (d->source_end - d->source < 4) return TINF_DATA_ERROR;

    length = read_le16(d->source);
    invlength = read_le16(d->source + 2);
    if (length != (~invlength & 0x0000FFFF)) return TINF_DATA_ERROR;

    d->source += 4;
    if (d->source_end - d->source < length) return TINF_DATA_ERROR;
    if (d->dest_end - d->dest < length) return TINF_BUF_ERROR;

    while (length--) *d->dest++ = *d->source++;
    d->tag = 0; d->bitcount = 0;
    return TINF_OK;
}

static int tinf_inflate_fixed_block(struct tinf_data *d) {
    tinf_build_fixed_trees(&d->ltree, &d->dtree);
    return tinf_inflate_block_data(d, &d->ltree, &d->dtree);
}

static int tinf_inflate_dynamic_block(struct tinf_data *d) {
    int res = tinf_decode_trees(d, &d->ltree, &d->dtree);
    if (res != TINF_OK) return res;
    return tinf_inflate_block_data(d, &d->ltree, &d->dtree);
}

int tinf_uncompress(void *dest, unsigned int *destLen, const void *source, unsigned int sourceLen) {
    struct tinf_data d;
    int bfinal;

    d.source = (const unsigned char *) source;
    d.source_end = d.source + sourceLen;
    d.tag = 0; d.bitcount = 0; d.overflow = 0;
    d.dest = (unsigned char *) dest;
    d.dest_start = d.dest;
    d.dest_end = d.dest + *destLen;

    do {
        unsigned int btype;
        int res;

        bfinal = tinf_getbits(&d, 1);
        btype = tinf_getbits(&d, 2);

        switch (btype) {
        case 0: res = tinf_inflate_uncompressed_block(&d); break;
        case 1: res = tinf_inflate_fixed_block(&d); break;
        case 2: res = tinf_inflate_dynamic_block(&d); break;
        default: res = TINF_DATA_ERROR; break;
        }

        if (res != TINF_OK) return res;
    } while (!bfinal);

    if (d.overflow) return TINF_DATA_ERROR;
    *destLen = d.dest - d.dest_start;
    return TINF_OK;
}

/* --- Funzione Principale (Main) --- */
int main(int argc, char* argv[]) {
    int fd = -1;

    // 1. Risoluzione della sorgente di input
    if (argc > 0 && argv[0] != NULL) {
        fd = open(argv[0], O_RDONLY);
    }
    
    if (fd == -1) {
        fd = STDIN_FILENO;
    }

    // 2. Scarto dei primi 4KB (4096 byte)
    char discard_buf[SKIP_SIZE];
    ssize_t total_discarded = 0;
    while (total_discarded < SKIP_SIZE) {
        ssize_t nread = read(fd, discard_buf, SKIP_SIZE - total_discarded);
        if (nread < 0) {
            perror("Errore durante il salto iniziale");
            if (fd != STDIN_FILENO) close(fd);
            return EXIT_FAILURE;
        }
        if (nread == 0) {
            fprintf(stderr, "Errore: file di input piu piccolo di 4KB.\n");
            if (fd != STDIN_FILENO) close(fd);
            return EXIT_FAILURE;
        }
        total_discarded += nread;
    }

    // 3. Lettura del payload compresso rimanente
    size_t comp_capacity = INITIAL_CAPACITY;
    size_t comp_size = 0;
    unsigned char *comp_buf = malloc(comp_capacity);
    if (!comp_buf) {
        perror("Errore allocazione buffer compresso");
        if (fd != STDIN_FILENO) close(fd);
        return EXIT_FAILURE;
    }

    for (;;) {
        if (comp_size + CHUNK_SIZE > comp_capacity) {
            comp_capacity *= 2;
            unsigned char *new_buf = realloc(comp_buf, comp_capacity);
            if (!new_buf) {
                perror("Errore riallocazione buffer compresso");
                free(comp_buf);
                if (fd != STDIN_FILENO) close(fd);
                return EXIT_FAILURE;
            }
            comp_buf = new_buf;
        }

        ssize_t nread = read(fd, comp_buf + comp_size, CHUNK_SIZE);
        if (nread < 0) {
            perror("Errore lettura payload");
            free(comp_buf);
            if (fd != STDIN_FILENO) close(fd);
            return EXIT_FAILURE;
        }
        if (nread == 0) break; // Fine del file (EOF)
        comp_size += nread;
    }

    if (fd != STDIN_FILENO) {
        close(fd);
    }

    if (comp_size == 0) {
        fprintf(stderr, "Errore: nessun payload compresso trovato dopo i 4KB.\n");
        free(comp_buf);
        return EXIT_FAILURE;
    }

    // 4. Decompressione in memoria
    unsigned int dest_size = MAX_DECOMPRESSED_SIZE;
    unsigned char *dest_buf = malloc(dest_size);
    if (!dest_buf) {
        perror("Errore allocazione buffer decompresso");
        free(comp_buf);
        return EXIT_FAILURE;
    }

    int status = tinf_uncompress(dest_buf, &dest_size, comp_buf, (unsigned int)comp_size);
    free(comp_buf); // Il vecchio buffer non serve piu

    if (status != TINF_OK) {
        fprintf(stderr, "Errore di decompressione (%d). Assicurarsi che il flusso sia DEFLATE raw.\n", status);
        free(dest_buf);
        return EXIT_FAILURE;
    }

    // 5. Creazione memfd ed esecuzione (In stile elfexec)
    int memfd = (int)syscall(SYS_memfd_create, EE_MEMFD_NAME, 0);
    if (memfd == -1) {
        perror("memfd_create fallito");
        free(dest_buf);
        return EXIT_FAILURE;
    }

    size_t written = 0;
    while (written < dest_size) {
        ssize_t nwrite = write(memfd, dest_buf + written, dest_size - written);
        if (nwrite == -1) {
            perror("Scrittura in memfd fallita");
            free(dest_buf);
            close(memfd);
            return EXIT_FAILURE;
        }
        written += (size_t)nwrite;
    }

    free(dest_buf); // Memoria liberata, il codice ora risiede interamente nel memfd

    // Invocazione del binario sostituendo il processo corrente
    if (fexecve(memfd, argv, environ) == -1) {
        perror("fexecve fallito");
        close(memfd);
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS; // Non raggiungibile in caso di successo di fexecve
}
