echo "Formatting the whole codebase"
v fmt -w .
clear
echo "Done formatting!"

echo "Building Shaders!"
v shader assets/osu/shaders/slider.glsl -l glsl330
echo "Done building Shaders!"


echo "Building Kurarin!"
v -cc clang -gc boehm -d release_unique .
echo "Done building!"

echo "Getting sample map!"
wget https://hatsune-miku.has.rocks/r/hikari.zip 
mkdir assets/osu/maps/hikari -p
unzip hikari.zip -d assets/osu/maps/hikari 

echo "Getting sample map!"

mkdir build -p
mkdir build/assets -p
mkdir build/assets/osu -p
mkdir build/assets/osu/maps/hikari -p


cp kurarin build/ -r
cp assets/common build/assets/ -r
cp assets/osu/shaders build/assets/osu/shaders -r
cp assets/osu/skins build/assets/osu/skins -r
cp "assets/osu/maps/hikari" build/assets/osu/maps -r

cd build
zip -r ../linux_x64.zip .
cd ..
rm -rf build/