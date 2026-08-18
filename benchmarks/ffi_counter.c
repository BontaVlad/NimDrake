#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef void *duckdb_data_chunk;
typedef void *duckdb_vector;
typedef void *garrow_record_batch;
typedef uint64_t idx_t;
typedef int gboolean;

static uint64_t data_chunk_get_vector_calls;
static uint64_t vector_reference_vector_calls;
static uint64_t vector_get_column_type_calls;
static uint64_t list_child_calls;
static uint64_t struct_child_calls;
static uint64_t array_child_calls;
static uint64_t garrow_record_batch_export_calls;
static uint64_t garrow_record_batch_export_schema_calls;

gboolean garrow_record_batch_export(
    garrow_record_batch batch, void **array, void **schema, void **error) {
    static gboolean (*real)(garrow_record_batch, void **, void **, void **);
    if (!real) {
        real = (gboolean (*)(garrow_record_batch, void **, void **, void **))
            dlsym(RTLD_NEXT, "garrow_record_batch_export");
    }
    ++garrow_record_batch_export_calls;
    if (schema != NULL) ++garrow_record_batch_export_schema_calls;
    return real(batch, array, schema, error);
}

duckdb_vector duckdb_data_chunk_get_vector(duckdb_data_chunk chunk, idx_t index) {
    static duckdb_vector (*real)(duckdb_data_chunk, idx_t);
    if (!real) real = (duckdb_vector (*)(duckdb_data_chunk, idx_t))dlsym(RTLD_NEXT, "duckdb_data_chunk_get_vector");
    ++data_chunk_get_vector_calls;
    return real(chunk, index);
}

void duckdb_vector_reference_vector(duckdb_vector target, duckdb_vector source) {
    static void (*real)(duckdb_vector, duckdb_vector);
    if (!real) real = (void (*)(duckdb_vector, duckdb_vector))dlsym(RTLD_NEXT, "duckdb_vector_reference_vector");
    ++vector_reference_vector_calls;
    real(target, source);
}

void *duckdb_vector_get_column_type(duckdb_vector vector) {
    static void *(*real)(duckdb_vector);
    if (!real) real = (void *(*)(duckdb_vector))dlsym(RTLD_NEXT, "duckdb_vector_get_column_type");
    ++vector_get_column_type_calls;
    return real(vector);
}

duckdb_vector duckdb_list_vector_get_child(duckdb_vector vector) {
    static duckdb_vector (*real)(duckdb_vector);
    if (!real) real = (duckdb_vector (*)(duckdb_vector))dlsym(RTLD_NEXT, "duckdb_list_vector_get_child");
    ++list_child_calls;
    return real(vector);
}

duckdb_vector duckdb_struct_vector_get_child(duckdb_vector vector, idx_t index) {
    static duckdb_vector (*real)(duckdb_vector, idx_t);
    if (!real) real = (duckdb_vector (*)(duckdb_vector, idx_t))dlsym(RTLD_NEXT, "duckdb_struct_vector_get_child");
    ++struct_child_calls;
    return real(vector, index);
}

duckdb_vector duckdb_array_vector_get_child(duckdb_vector vector) {
    static duckdb_vector (*real)(duckdb_vector);
    if (!real) real = (duckdb_vector (*)(duckdb_vector))dlsym(RTLD_NEXT, "duckdb_array_vector_get_child");
    ++array_child_calls;
    return real(vector);
}

__attribute__((destructor)) static void write_counts(void) {
    const char *path = getenv("NIMDRAKE_FFI_OUTPUT");
    if (!path) return;
    FILE *file = fopen(path, "w");
    if (!file) return;
    fprintf(file,
        "{\n"
        "  \"duckdb_data_chunk_get_vector\": %llu,\n"
        "  \"duckdb_vector_reference_vector\": %llu,\n"
        "  \"duckdb_vector_get_column_type\": %llu,\n"
        "  \"duckdb_list_vector_get_child\": %llu,\n"
        "  \"duckdb_struct_vector_get_child\": %llu,\n"
        "  \"duckdb_array_vector_get_child\": %llu,\n"
        "  \"garrow_record_batch_export\": %llu,\n"
        "  \"garrow_record_batch_export_schema\": %llu\n"
        "}\n",
        (unsigned long long)data_chunk_get_vector_calls,
        (unsigned long long)vector_reference_vector_calls,
        (unsigned long long)vector_get_column_type_calls,
        (unsigned long long)list_child_calls,
        (unsigned long long)struct_child_calls,
        (unsigned long long)array_child_calls,
        (unsigned long long)garrow_record_batch_export_calls,
        (unsigned long long)garrow_record_batch_export_schema_calls);
    fclose(file);
}
