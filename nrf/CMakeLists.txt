cmake_minimum_required(VERSION 3.20.0)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})

project(hum_sensor)

target_include_directories(app PRIVATE include)

target_sources(app PRIVATE 
    src/main.c
    src/sht31d.c
)
