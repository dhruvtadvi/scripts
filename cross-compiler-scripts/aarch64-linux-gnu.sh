set -e
TARGET=aarch64-linux-gnu
BUILD_DIR=$(pwd)/out
CFLAGS="-O3"
CXXFLAGS=$CFLAGS
JOBS=$(nproc --all)
export PATH=$PATH:$BUILD_DIR/bin

DOWNLOAD_SOURCES=(
	"https://ftp.gnu.org/gnu/binutils/binutils-2.42.tar.gz" \
	"https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.gz" \
	"https://ftp.gnu.org/gnu/glibc/glibc-2.39.tar.gz" \
	"https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz" 
)

#download all files if doesn't exits
for download_links in ${DOWNLOAD_SOURCES[@]}; do
	base_file_name=$(basename $download_links)
	dir_name=$(echo $base_file_name | cut -d "-" -f 1)	
	mkdir -p downloads
	if [ ! -f downloads/$base_file_name ]; then 	
		wget -O downloads/$base_file_name $download_links
	fi
	
	#extract all the files which was previously downloaded
	if [ ! -d $dir_name-* ]; then	
		echo "extracing files"
		tar -xf downloads/$base_file_name
	fi
done

build_binutils() {
	cd binutils-*
	if [ -d build ]; then rm -rf build; fi
	mkdir build && cd build
	../configure --prefix=$BUILD_DIR \
		--target=$TARGET \
		--disable-multilib

	make -j$JOBS
	make install -j$JOBS
	cd ../..
}

build_kernel_headers() {
	cd linux-*
	make ARCH=arm64 INSTALL_HDR_PATH=$BUILD_DIR/$TARGET headers_install
	cd ..
}


build_gcc() {
	cd gcc-*
	if [ -d build ]; then rm -rf build; fi
	mkdir build && cd build
	../configure --prefix=$BUILD_DIR \
		--target=$TARGET \
		--disable-multilib \
		--disable-libsanitizer \
		--enable-languages=c,c++

	make all-gcc -j$JOBS
	make install-gcc -j$JOBS
	cd ../..
}


build_glibc() {
	cd glibc-*
	if [ -d build ]; then rm -rf build;fi
	mkdir build -p
	cd build

	../configure \
		--prefix=$BUILD_DIR/$TARGET \
		--build=$MACHTYPE \
		--host=$TARGET \
		--target=$TARGET \
		--disable-multilib \
		--with-headers=$BUILD_DIR/$TARGET/include \
		libc_cv_forced_unwind=yes

	make install-bootstrap-headers=yes install-headers
	make csu/subdir_lib -j$JOBS
	install csu/crt1.o csu/crti.o csu/crtn.o $BUILD_DIR/$TARGET/lib
	$TARGET-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o $BUILD_DIR/$TARGET/lib/libc.so
	touch $BUILD_DIR/$TARGET/include/gnu/stubs.h
	cd ../..

	cd gcc-*/build
	make all-target-libgcc -j$JOBS
	make install-target-libgcc
	cd ../..

	cd glibc-*/build
	make -j$JOBS
	make install
	cd ../..

	cd gcc-*/build
	make -j$JOBS
	make install
	cd ../..
}

build_binutils
build_kernel_headers
build_gcc
build_glibc
