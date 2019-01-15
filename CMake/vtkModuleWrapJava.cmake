#[==[.md
# `vtkModuleWrapJava`

This module includes logic necessary in order to wrap VTK modules using VTK's
Java wrapping logic.
#]==]

#[==[.md INTERNAL
## Wrapping a single module

This function generates the wrapped sources for a module. It places the list of
generated source files and Java source files in variables named in the second
and third arguments, respectively.

```
_vtk_module_wrap_java_sources(<module> <sources> <classes>)
```
#]==]
function (_vtk_module_wrap_java_sources module sources java_sources)
  _vtk_module_get_module_property("${module}"
    PROPERTY  "exclude_wrap"
    VARIABLE  _vtk_java_exclude_wrap)
  if (_vtk_java_exclude_wrap)
    return ()
  endif ()

  set(_vtk_java_args_file "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${_vtk_java_library_name}-java.$<CONFIGURATION>.args")
  set(_vtk_java_init_data_file "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${_vtk_java_library_name}-java-init.data")

  set(_vtk_java_genex_compile_definitions
    "$<TARGET_PROPERTY:${_vtk_java_target_name},COMPILE_DEFINITIONS>")
  set(_vtk_java_genex_include_directories
    "$<TARGET_PROPERTY:${_vtk_java_target_name},INCLUDE_DIRECTORIES>")
  file(GENERATE
    OUTPUT  "${_vtk_java_args_file}"
    CONTENT "$<$<BOOL:${_vtk_java_genex_compile_definitions}>:\n-D\"$<JOIN:${_vtk_java_genex_compile_definitions},\"\n-D\">\">\n
$<$<BOOL:${_vtk_java_genex_include_directories}>:\n-I\"$<JOIN:${_vtk_java_genex_include_directories},\"\n-I\">\">\n")

  _vtk_module_get_module_property("${module}"
    PROPERTY  "hierarchy"
    VARIABLE  _vtk_java_hierarchy_file)

  get_property(_vtk_java_is_imported
    TARGET    "${module}"
    PROPERTY  "IMPORTED")
  if (_vtk_java_is_imported OR CMAKE_GENERATOR MATCHES "Ninja")
    set(_vtk_java_command_depend "${_vtk_java_hierarchy_file}")
  else ()
    if (TARGET "${_vtk_java_target_name}-hierarchy")
      set(_vtk_java_command_depend "${_vtk_java_target_name}-hierarchy")
    else ()
      message(FATAL_ERROR
        "The ${module} hierarchy file is attached to a non-imported target "
        "and a hierarchy target (${_vtk_java_target_name}-hierarchy) is "
        "missing.")
    endif ()
  endif ()

  set(_vtk_java_sources)
  set(_vtk_java_java_sources)

  _vtk_module_get_module_property("${module}"
    PROPERTY  "headers"
    VARIABLE  _vtk_java_headers)
  set(_vtk_java_classes)
  foreach (_vtk_java_header IN LISTS _vtk_java_headers)
    get_filename_component(_vtk_java_basename "${_vtk_java_header}" NAME_WE)
    list(APPEND _vtk_java_classes
      "${_vtk_java_basename}")

    set(_vtk_java_source_output
      "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${_vtk_java_basename}Java.cxx")
    list(APPEND _vtk_java_sources
      "${_vtk_java_source_output}")

    add_custom_command(
      OUTPUT  "${_vtk_java_source_output}"
      COMMAND VTK::WrapJava
              "@${_vtk_java_args_file}"
              -o "${_vtk_java_source_output}"
              "${_vtk_java_header}"
              --types "${_vtk_java_hierarchy_file}"
      IMPLICIT_DEPENDS
              CXX "${_vtk_java_header}"
      COMMENT "Generating Java wrapper sources for ${_vtk_java_basename}"
      DEPENDS
        VTK::WrapJava
        "${_vtk_java_header}"
        "${_vtk_java_args_file}"
        "${_vtk_java_command_depend}")

    set(_vtk_java_java_source_output
      "${_vtk_java_JAVA_OUTPUT}/${_vtk_java_basename}.java")
    list(APPEND _vtk_java_java_sources
      "${_vtk_java_java_source_output}")

    add_custom_command(
      OUTPUT  "${_vtk_java_java_source_output}"
      COMMAND VTK::ParseJava
              "@${_vtk_java_args_file}"
              -o "${_vtk_java_java_source_output}"
              "${_vtk_java_header}"
              --types "${_vtk_java_hierarchy_file}"
      IMPLICIT_DEPENDS
              CXX "${_vtk_java_header}"
      COMMENT "Generating Java sources for ${_vtk_java_basename}"
      DEPENDS
        VTK::ParseJava
        "${_vtk_java_header}"
        "${_vtk_java_args_file}"
        "${_vtk_java_hierarchy_file}")
  endforeach ()

  set("${sources}"
    "${_vtk_java_sources}"
    PARENT_SCOPE)

  set("${java_sources}"
    "${_vtk_java_java_sources}"
    PARENT_SCOPE)
endfunction ()

#[==[.md INTERNAL
## Generating a Java JNI library

A single JNI library may consist of the Java wrappings of multiple VTK modules.
This is useful for kit-based builds where the modules part of the same kit
belong to the same JNI library as well.

```
_vtk_module_wrap_java_library(<name> <module>...)
```

The first argument is the name of the JNI library. The remaining arguments are
VTK modules to include in the JNI library.

The remaining information it uses is assumed to be provided by the
`vtk_module_wrap_java` function.
#]==]
function (_vtk_module_wrap_java_library name)
  set(_vtk_java_library_sources)
  set(_vtk_java_library_java_sources)
  foreach (_vtk_java_module IN LISTS ARGN)
    _vtk_module_get_module_property("${_vtk_java_module}"
      PROPERTY  "exclude_wrap"
      VARIABLE  _vtk_java_exclude_wrap)
    if (_vtk_java_exclude_wrap)
      continue ()
    endif ()
    _vtk_module_real_target(_vtk_java_target_name "${_vtk_java_module}")
    _vtk_module_get_module_property("${_vtk_java_module}"
      PROPERTY  "library_name"
      VARIABLE  _vtk_java_library_name)
    _vtk_module_wrap_java_sources("${_vtk_java_module}" _vtk_java_sources _vtk_java_java_sources)
    list(APPEND _vtk_java_library_sources
      ${_vtk_java_sources})
    list(APPEND _vtk_java_library_java_sources
      ${_vtk_java_java_sources})
  endforeach ()

  if (NOT _vtk_java_library_sources)
    return ()
  endif ()

  set(_vtk_java_target "${name}Java")

  add_library("${_vtk_java_target}" SHARED
    ${_vtk_java_library_sources})
  add_custom_target("${_vtk_java_target}-java-sources"
    DEPENDS
      ${_vtk_java_library_java_sources})
  add_dependencies("${_vtk_java_target}"
    "${_vtk_java_target}-java-sources")
  if (MINGW)
    set_property(TARGET "${_vtk_java_target}"
      PROPERTY
        PREFIX "")
  endif ()
  if (APPLE)
    set_property(TARGET "${_vtk_java_target}"
      PROPERTY
        SUFFIX ".jnilib")
  endif ()
  set_property(TARGET "${_vtk_java_target}"
    PROPERTY
      "_vtk_module_java_files" "${_vtk_java_library_java_sources}")

  vtk_module_autoinit(
    MODULES ${ARGN}
    TARGETS "${_vtk_java_target}")

  target_link_libraries("${_vtk_java_target}"
    PRIVATE
      ${ARGN}
      VTK::Java)
endfunction ()

#[==[.md
## Wrapping a set of VTK modules in Java

```
vtk_module_wrap_java(
  MODULES <module>...
  [WRAPPED_MODULES <varname>]

  [JAVA_OUTPUT <destination>])
```

  * `MODULES`: (Required) The list of modules to wrap.
  * `WRAPPED_MODULES`: (Recommended) Not all modules are wrappable. This
    variable will be set to contain the list of modules which were wrapped.
  * `JAVA_OUTPUT`: Defaults to `${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles`. Java
    source files are written to this directory. After generation, the files may
    be compiled as needed.

For each wrapped module, a `<module>Java` target will be created. These targets
will have a `_vtk_module_java_files` property which is the list of generated
Java source files for that target.

For dependency purposes, the `<module>Java-java-sources` target may also be
used.
#]==]
function (vtk_module_wrap_java)
  cmake_parse_arguments(_vtk_java
    ""
    "JAVA_OUTPUT;WRAPPED_MODULES"
    "MODULES"
    ${ARGN})

  if (_vtk_java_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR
      "Unparsed arguments for vtk_module_wrap_java: "
      "${_vtk_java_UNPARSED_ARGUMENTS}")
  endif ()

  if (NOT _vtk_java_JAVA_OUTPUT)
    set(_vtk_java_JAVA_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles")
  endif ()

  if (NOT _vtk_java_MODULES)
    message(WARNING
      "No modules were requested for java wrapping.")
    return ()
  endif ()

  set(_vtk_java_all_wrapped_modules)
  foreach (_vtk_java_module IN LISTS _vtk_java_MODULES)
    _vtk_module_get_module_property("${_vtk_java_module}"
      PROPERTY  "library_name"
      VARIABLE  _vtk_java_exclude_wrap)
    _vtk_module_get_module_property("${_vtk_java_module}"
      PROPERTY  "library_name"
      VARIABLE  _vtk_java_library_name)
    _vtk_module_wrap_java_library("${_vtk_java_library_name}" "${_vtk_java_module}")

    if (TARGET "${_vtk_java_library_name}Java")
      list(APPEND _vtk_java_all_wrapped_modules
        "${_vtk_java_module}")
    endif ()
  endforeach ()

  if (NOT _vtk_java_all_wrapped_modules)
    message(FATAL_ERROR
      "No modules given could be wrapped.")
  endif ()

  if (DEFINED _vtk_java_WRAPPED_MODULES)
    set("${_vtk_java_WRAPPED_MODULES}"
      "${_vtk_java_all_wrapped_modules}"
      PARENT_SCOPE)
  endif ()
endfunction ()
