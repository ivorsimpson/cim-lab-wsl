# CMakeLists.txt for __PROJECT_NAME__
cmake_minimum_required(VERSION 3.18)

# If nvcc isn't on PATH (raw `cmake ..` from a non-interactive shell where
# bashrc didn't run), fall back to the canonical apt-install location. VS
# Code passes this explicitly via settings.json; this is the belt to that
# braces for terminals/scripts/CI.
if(NOT DEFINED CMAKE_CUDA_COMPILER AND EXISTS "/usr/local/cuda/bin/nvcc")
    set(CMAKE_CUDA_COMPILER "/usr/local/cuda/bin/nvcc")
endif()

project(__PROJECT_NAME__ LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# Lab GPUs are NVIDIA A4000 = Ampere SM 8.6. If you copy this project
# elsewhere, change the architecture below.
set(CMAKE_CUDA_ARCHITECTURES __CUDA_ARCH__)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(__PROJECT_NAME__ main.cu)

find_package(CUDAToolkit REQUIRED)
target_link_libraries(__PROJECT_NAME__ PRIVATE
    CUDA::cudart
    # CUDA::cublas
    # CUDA::curand
    # CUDA::cufft
)

message(STATUS "Project:    __PROJECT_NAME__")
message(STATUS "CUDA arch:  ${CMAKE_CUDA_ARCHITECTURES}")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "nvcc:       ${CMAKE_CUDA_COMPILER}")
