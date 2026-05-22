// main.cu - __PROJECT_NAME__
// Minimal but real CUDA: vector addition on the GPU.
// If this builds and runs, your whole toolchain is working.

#include <cstdio>
#include <cstdlib>
#include <vector>
#include <cuda_runtime.h>

#define CUDA_CHECK(expr)                                                    \
    do {                                                                    \
        cudaError_t err__ = (expr);                                         \
        if (err__ != cudaSuccess) {                                         \
            std::fprintf(stderr, "CUDA error at %s:%d: %s\n",               \
                         __FILE__, __LINE__, cudaGetErrorString(err__));    \
            std::exit(EXIT_FAILURE);                                        \
        }                                                                   \
    } while (0)

__global__ void vector_add(const float* a, const float* b, float* c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] + b[i];
}

int main() {
    int device = 0;
    CUDA_CHECK(cudaGetDevice(&device));
    cudaDeviceProp props{};
    CUDA_CHECK(cudaGetDeviceProperties(&props, device));
    std::printf("Device:       %s\n", props.name);
    std::printf("Compute cap:  %d.%d\n", props.major, props.minor);
    std::printf("SMs:          %d\n", props.multiProcessorCount);
    std::printf("Global mem:   %.1f GB\n",
                static_cast<double>(props.totalGlobalMem) / (1024.0 * 1024.0 * 1024.0));

    constexpr int N = 1 << 20;
    constexpr int BYTES = N * sizeof(float);

    std::vector<float> h_a(N), h_b(N), h_c(N, 0.0f);
    for (int i = 0; i < N; ++i) {
        h_a[i] = static_cast<float>(i);
        h_b[i] = static_cast<float>(2 * i);
    }

    float *d_a = nullptr, *d_b = nullptr, *d_c = nullptr;
    CUDA_CHECK(cudaMalloc(&d_a, BYTES));
    CUDA_CHECK(cudaMalloc(&d_b, BYTES));
    CUDA_CHECK(cudaMalloc(&d_c, BYTES));

    CUDA_CHECK(cudaMemcpy(d_a, h_a.data(), BYTES, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_b, h_b.data(), BYTES, cudaMemcpyHostToDevice));

    constexpr int THREADS_PER_BLOCK = 256;
    const int blocks = (N + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
    vector_add<<<blocks, THREADS_PER_BLOCK>>>(d_a, d_b, d_c, N);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    CUDA_CHECK(cudaMemcpy(h_c.data(), d_c, BYTES, cudaMemcpyDeviceToHost));

    int errors = 0;
    for (int i = 0; i < N; ++i) {
        const float expected = static_cast<float>(i) + static_cast<float>(2 * i);
        if (h_c[i] != expected) {
            if (errors < 5)
                std::fprintf(stderr, "  mismatch at %d: got %f, expected %f\n",
                             i, h_c[i], expected);
            ++errors;
        }
    }

    CUDA_CHECK(cudaFree(d_a));
    CUDA_CHECK(cudaFree(d_b));
    CUDA_CHECK(cudaFree(d_c));

    if (errors == 0) {
        std::printf("OK: %d elements, all correct.\n", N);
        return 0;
    } else {
        std::printf("FAIL: %d / %d elements were wrong.\n", errors, N);
        return 1;
    }
}
