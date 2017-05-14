cmake_minimum_required (VERSION 2.8)
cmake_policy (SET CMP0015 OLD)

set (CMAKE_BUILD_TYPE "" CACHE STRING "")

project (FUGITIVE)
set (FUGITIVE_VERSION_MAJOR 1)
set (FUGITIVE_VERSION_MINOR 0)

set (FUGITIVE_INSTALL_DIR "${CMAKE_INSTALL_PREFIX}/share/vim/")

# Copy files with 644 permissions
install(FILES plugin/fugitive.vim
    DESTINATION ${FUGITIVE_INSTALL_DIR}/addons/plugin/)
install(FILES doc/fugitive.txt
    DESTINATION ${FUGITIVE_INSTALL_DIR}/addons/doc/)
install(FILES registry/vim-fugitive.yaml
    DESTINATION ${FUGITIVE_INSTALL_DIR}/registry/)

