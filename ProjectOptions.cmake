include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(copy_files_supports_sanitizers)
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

macro(copy_files_setup_options)
  option(copy_files_ENABLE_HARDENING "Enable hardening" ON)
  option(copy_files_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    copy_files_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    copy_files_ENABLE_HARDENING
    OFF)

  copy_files_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR copy_files_PACKAGING_MAINTAINER_MODE)
    option(copy_files_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(copy_files_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(copy_files_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(copy_files_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(copy_files_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(copy_files_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(copy_files_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(copy_files_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(copy_files_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(copy_files_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(copy_files_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(copy_files_ENABLE_PCH "Enable precompiled headers" OFF)
    option(copy_files_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(copy_files_ENABLE_IPO "Enable IPO/LTO" ON)
    option(copy_files_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(copy_files_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(copy_files_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(copy_files_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(copy_files_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(copy_files_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(copy_files_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(copy_files_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(copy_files_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(copy_files_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(copy_files_ENABLE_PCH "Enable precompiled headers" OFF)
    option(copy_files_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      copy_files_ENABLE_IPO
      copy_files_WARNINGS_AS_ERRORS
      copy_files_ENABLE_USER_LINKER
      copy_files_ENABLE_SANITIZER_ADDRESS
      copy_files_ENABLE_SANITIZER_LEAK
      copy_files_ENABLE_SANITIZER_UNDEFINED
      copy_files_ENABLE_SANITIZER_THREAD
      copy_files_ENABLE_SANITIZER_MEMORY
      copy_files_ENABLE_UNITY_BUILD
      copy_files_ENABLE_CLANG_TIDY
      copy_files_ENABLE_CPPCHECK
      copy_files_ENABLE_COVERAGE
      copy_files_ENABLE_PCH
      copy_files_ENABLE_CACHE)
  endif()

  copy_files_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (copy_files_ENABLE_SANITIZER_ADDRESS OR copy_files_ENABLE_SANITIZER_THREAD OR copy_files_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(copy_files_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(copy_files_global_options)
  if(copy_files_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    copy_files_enable_ipo()
  endif()

  copy_files_supports_sanitizers()

  if(copy_files_ENABLE_HARDENING AND copy_files_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR copy_files_ENABLE_SANITIZER_UNDEFINED
       OR copy_files_ENABLE_SANITIZER_ADDRESS
       OR copy_files_ENABLE_SANITIZER_THREAD
       OR copy_files_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${copy_files_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${copy_files_ENABLE_SANITIZER_UNDEFINED}")
    copy_files_enable_hardening(copy_files_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(copy_files_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(copy_files_warnings INTERFACE)
  add_library(copy_files_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  copy_files_set_project_warnings(
    copy_files_warnings
    ${copy_files_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(copy_files_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    copy_files_configure_linker(copy_files_options)
  endif()

  include(cmake/Sanitizers.cmake)
  copy_files_enable_sanitizers(
    copy_files_options
    ${copy_files_ENABLE_SANITIZER_ADDRESS}
    ${copy_files_ENABLE_SANITIZER_LEAK}
    ${copy_files_ENABLE_SANITIZER_UNDEFINED}
    ${copy_files_ENABLE_SANITIZER_THREAD}
    ${copy_files_ENABLE_SANITIZER_MEMORY})

  set_target_properties(copy_files_options PROPERTIES UNITY_BUILD ${copy_files_ENABLE_UNITY_BUILD})

  if(copy_files_ENABLE_PCH)
    target_precompile_headers(
      copy_files_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(copy_files_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    copy_files_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(copy_files_ENABLE_CLANG_TIDY)
    copy_files_enable_clang_tidy(copy_files_options ${copy_files_WARNINGS_AS_ERRORS})
  endif()

  if(copy_files_ENABLE_CPPCHECK)
    copy_files_enable_cppcheck(${copy_files_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(copy_files_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    copy_files_enable_coverage(copy_files_options)
  endif()

  if(copy_files_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(copy_files_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(copy_files_ENABLE_HARDENING AND NOT copy_files_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR copy_files_ENABLE_SANITIZER_UNDEFINED
       OR copy_files_ENABLE_SANITIZER_ADDRESS
       OR copy_files_ENABLE_SANITIZER_THREAD
       OR copy_files_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    copy_files_enable_hardening(copy_files_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
