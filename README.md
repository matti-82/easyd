# easyd

Extension to the D standard library to make coding easier.

## Features

List Module

- Linked list with fast block-wise memory allocation
- Selection class to allow filtering and sorting of lists and arrays without modifying them
- ListIndex class to allow fast hash-based access to list items

String Module

- various ways to get substrings
- find and replace
- conversion and concatenation with delimiters

Stream Module

- read and write streams

Unix Module

- convert paths to absolute and relative
- build paths
- access dirs
- get user name
- make output of processes available as stream

Thread Module

- convienience function to start threads
- realtime support (execute code without being intercepted by GC)

Base Module

- Several helper functions, e.g. for event handling
- Template to create value types based on classes

Currently not all modules are published yet. Modules for serialization and GUIs will follow within the next months.

Examples how to use easyd can be found in the unittests in the .d files.
