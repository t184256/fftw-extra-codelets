#!/bin/bash -ue

# Build FFTW with extra codelets.
# Source archive must be prepared in advance, see other script!
# Does not require OCaml.

. configuration

FFTW="${FFTW}-with-extra-codelets"

rm -rf ./$FFTW
tar xzf $FFTW.tar.gz
cd $FFTW

mkdir -p install
PREFIX=$(realpath install)

echo Configuring...
./configure $FLAGS --prefix="$PREFIX"

echo Building FFTW with extra codelets...
make -j4
echo Installing FFTW with extra codelets...
make install
echo Done installing FFTW with extra codelets
