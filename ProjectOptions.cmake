include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(test0_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(test0_setup_options)
  option(test0_ENABLE_HARDENING "Enable hardening" ON)
  option(test0_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    test0_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    test0_ENABLE_HARDENING
    OFF)

  test0_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR test0_PACKAGING_MAINTAINER_MODE)
    option(test0_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(test0_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(test0_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(test0_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(test0_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(test0_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(test0_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(test0_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(test0_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(test0_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(test0_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(test0_ENABLE_PCH "Enable precompiled headers" OFF)
    option(test0_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(test0_ENABLE_IPO "Enable IPO/LTO" ON)
    option(test0_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(test0_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(test0_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(test0_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(test0_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(test0_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(test0_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(test0_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(test0_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(test0_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(test0_ENABLE_PCH "Enable precompiled headers" OFF)
    option(test0_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      test0_ENABLE_IPO
      test0_WARNINGS_AS_ERRORS
      test0_ENABLE_USER_LINKER
      test0_ENABLE_SANITIZER_ADDRESS
      test0_ENABLE_SANITIZER_LEAK
      test0_ENABLE_SANITIZER_UNDEFINED
      test0_ENABLE_SANITIZER_THREAD
      test0_ENABLE_SANITIZER_MEMORY
      test0_ENABLE_UNITY_BUILD
      test0_ENABLE_CLANG_TIDY
      test0_ENABLE_CPPCHECK
      test0_ENABLE_COVERAGE
      test0_ENABLE_PCH
      test0_ENABLE_CACHE)
  endif()

  test0_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (test0_ENABLE_SANITIZER_ADDRESS OR test0_ENABLE_SANITIZER_THREAD OR test0_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(test0_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(test0_global_options)
  if(test0_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    test0_enable_ipo()
  endif()

  test0_supports_sanitizers()

  if(test0_ENABLE_HARDENING AND test0_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR test0_ENABLE_SANITIZER_UNDEFINED
       OR test0_ENABLE_SANITIZER_ADDRESS
       OR test0_ENABLE_SANITIZER_THREAD
       OR test0_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${test0_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${test0_ENABLE_SANITIZER_UNDEFINED}")
    test0_enable_hardening(test0_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(test0_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(test0_warnings INTERFACE)
  add_library(test0_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  test0_set_project_warnings(
    test0_warnings
    ${test0_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(test0_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(test0_options)
  endif()

  include(cmake/Sanitizers.cmake)
  test0_enable_sanitizers(
    test0_options
    ${test0_ENABLE_SANITIZER_ADDRESS}
    ${test0_ENABLE_SANITIZER_LEAK}
    ${test0_ENABLE_SANITIZER_UNDEFINED}
    ${test0_ENABLE_SANITIZER_THREAD}
    ${test0_ENABLE_SANITIZER_MEMORY})

  set_target_properties(test0_options PROPERTIES UNITY_BUILD ${test0_ENABLE_UNITY_BUILD})

  if(test0_ENABLE_PCH)
    target_precompile_headers(
      test0_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(test0_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    test0_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(test0_ENABLE_CLANG_TIDY)
    test0_enable_clang_tidy(test0_options ${test0_WARNINGS_AS_ERRORS})
  endif()

  if(test0_ENABLE_CPPCHECK)
    test0_enable_cppcheck(${test0_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(test0_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    test0_enable_coverage(test0_options)
  endif()

  if(test0_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(test0_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(test0_ENABLE_HARDENING AND NOT test0_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR test0_ENABLE_SANITIZER_UNDEFINED
       OR test0_ENABLE_SANITIZER_ADDRESS
       OR test0_ENABLE_SANITIZER_THREAD
       OR test0_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    test0_enable_hardening(test0_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
