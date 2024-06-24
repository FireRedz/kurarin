# Variables
with_gc=true # True by default
gc_type="boehm"

make_shaders=true
shaders_dir="assets/osu/shaders/slider.glsl"

is_debug=false
is_prod=false

compiler="clang"

build_command="v"

where="." # This directory

# Misc Variables
what_mode="Development"


# Functions
format() {
    v fmt -w .
}

build_shaders() {
    v shader $shaders_dir -l glsl330
}

build() {
    # Garbage collector
    if [ "$with_gc" = "true" ]; then
        build_command+=" -gc $gc_type"
    fi

    # Debug
    if [ "$is_debug" = "true" ]; then
        build_command+=" -cg -g"
        build_command+=" -d trace_sokol_memory"
        what_mode="Debug"
    fi

    # Prod build
    if [ "$is_prod" = "true" ]; then
        build_command+=" -prod"
        what_mode="Production"
    fi

    # Compiler
    # TODO: use cc or smth
    build_command+=" -cc $compiler"

    # What to compile
    build_command+=" $where"

    # Clear shit
    clear

    # Print some stuff
    echo "Mode: $what_mode"
    echo "Compiler: $compiler"
    echo "GC: $gc_type"
    echo "Rebuild Shaders: $make_shaders"
    
    # TODO: scuffed
    if [ "$make_shaders" = "true" ]; then
        format 
        build_shaders && eval "$build_command"
    else 
        format
        eval "$build_command"
    fi
}

# Utils
run_program() {
    echo "Running Program!" &&
    ./dementia
}

# Build type
case $1 in 
    "--prod"|"--production"|"-prod")
        is_prod=true
        ;;

    "--debug"|"--debug"|"-debug")
        is_debug=true
        ;;

    "--debug_raw"|"-debug_raw")
        with_gc=false
        ;;
    *)
esac

# Nothing passed, build with devel settings
build

# TODO: not familiar with bash, make this better.
case $1 in 
    "--run"|"-run")
        run_program
        ;;

    *)
esac

case $2 in 
    "--run"|"-run")
        run_program
        ;;

    *)
esac
