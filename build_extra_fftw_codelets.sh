#!/bin/bash -ue

# Build extra codelets for FFTW. Requires OCaml, autotools and other stuff.
# Better use ccache!

. configuration

# Extra codelets
E00=""
E00_NO=""
for ((i=2; i<=$E00_UP_TO; i++)); do
	SUBOPTIMALS_FOUND=""
	if (( i > E00_FORCED_UP_TO )); then
		for SUBOPTIMAL_FACTOR in $SUBOPTIMAL_FACTORS; do
			CHECK_NUMBER=$(($i - 1))  # check - 1 for DCT (REDFT00 and friends)
			# see http://www.fftw.org/fftw3_doc/Real_002dto_002dReal-Transforms.html
			if (( $CHECK_NUMBER % $SUBOPTIMAL_FACTOR == 0 )); then
				SUBOPTIMALS_FOUND="$SUBOPTIMALS_FOUND&$SUBOPTIMAL_FACTOR"
			fi
		done
	fi
	if [ -n "$SUBOPTIMALS_FOUND" ]; then
		E00_NO="$E00_NO $i($CHECK_NUMBER$SUBOPTIMALS_FOUND)"
	else
		E00="$E00 e00_$i.c"
	fi
done
echo "Not gotta build e00 codelets due to suboptimal factorization for sizes:"
echo $E00_NO | fold -s
echo "Gotta build the following e00 codelets:"
echo $E00 | fold -s


O00=""
O00_NO=""
for ((i=2; i<=$O00_UP_TO; i++)); do
	SUBOPTIMALS_FOUND=""
	if (( i > O00_FORCED_UP_TO )); then
		for SUBOPTIMAL_FACTOR in $SUBOPTIMAL_FACTORS; do
			CHECK_NUMBER=$(($i + 1))  # check + 1 for DST (RODFT00 and friends)
			# see http://www.fftw.org/fftw3_doc/Real_002dto_002dReal-Transforms.html
			if (( $CHECK_NUMBER % $SUBOPTIMAL_FACTOR == 0 )); then
				SUBOPTIMALS_FOUND="$SUBOPTIMALS_FOUND&$SUBOPTIMAL_FACTOR"
			fi
		done
	fi
	if [ -n "$SUBOPTIMALS_FOUND" ]; then
		O00_NO="$O00_NO $i($CHECK_NUMBER$SUBOPTIMALS_FOUND)"
	else
		O00="$O00 o00_$i.c"
	fi
done
echo "Not gotta build o00 codelets due to suboptimal factorization for sizes:"
echo $O00_NO | fold -s
echo "Gotta build the following o00 codelets:"
echo $O00 | fold -s


pushd () {
	command pushd "$@" > /dev/null
}
popd () {
	command popd "$@" > /dev/null
}

[ -r $FFTW.tar.gz ] || wget http://www.fftw.org/$FFTW.tar.gz

rm -rf ./tmp_building_extra_codelets
mkdir -p ./tmp_building_extra_codelets
pushd ./tmp_building_extra_codelets

tar xzf ../$FFTW.tar.gz
pushd $FFTW

mkdir -p install
PREFIX=$(realpath install)
FFTWDIR=$(pwd)

sed -i "s^O00 = .*^O00=$O00^" rdft/scalar/r2r/Makefile.am
sed -i "s^E00 = .*^E00=$E00^" rdft/scalar/r2r/Makefile.am

echo Configuring...
./bootstrap.sh "$FLAGS" --prefix="$PREFIX" >/dev/null 2>/dev/null

echo Extracting previously calculated codelets...
if [ -r ../../extra_codelets.tbz ]; then
      	tar xjf ../../extra_codelets.tbz --mtime now
fi

echo Building OCaml codelet generator...
make -s -j4 -C genfft >/dev/null 2>/dev/null

function pack_codelets {
	pushd $FFTWDIR
	tar -cjf ../../extra_codelets.tbz \
		$(ls rdft/scalar/r2r/e00_*.c rdft/scalar/r2r/o00_*.c)
	popd
}

echo Building r2r codelets...
pushd rdft/scalar/r2r
for FILE in $E00 $O00; do
	if [ -r $FILE ]; then
		echo not rebuilding $FILE
	else
		T_DATE=$(date -Iseconds)
		echo -ne "$T_DATE building $FILE... "
		T_START=$(date +%s%N)
		make $FILE 2>/dev/null >/dev/null
		T_END=$(date +%s%N)
		T_SEC=$((($T_END - $T_START) / 1000000000))
		T_MSEC=$((($T_END - $T_START) / 1000000 - $T_SEC * 1000))
		echo "$T_SEC.$T_MSEC s"
		#echo repacking with $FILE
		pack_codelets
	fi
done
popd

echo Packing final extra_codelets archive...
pack_codelets

echo Building everything else just to be sure everything worked...
touch -d '2000-01-01' genfft/gen_* COPYRIGHT  # do not rebuild old codelets
make -s -j4 >/dev/null 2>/dev/null
#make check
echo Cleaning up...
make -s clean >/dev/null 2>/dev/null
make -s distclean >/dev/null 2>/dev/null
popd

echo Packing up the whole source tree...
mv $FFTW $FFTW-with-extra-codelets
tar czf ../$FFTW-with-extra-codelets.tar.gz $FFTW-with-extra-codelets
popd
echo Cleaning up...
rm -rf ./tmp_building_extra_codelets
echo Done
