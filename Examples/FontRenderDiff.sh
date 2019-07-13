#!/bin/sh

mydir=`dirname "${0}"`

"$mydir"/../Build/FontRenderDiff \
    "$mydir"/Noto-2019/NotoSansDevanagari-Regular.ttf \
    "$mydir"/NotoSansDevanagari.test.txt \
    "$mydir/NotoSansDevanagariImages"

"$mydir"/../Build/FontRenderDiff \
    /Library/Fonts/Futura.ttc Futura-CondensedExtraBold \
    "$mydir"/Futura.test.txt \
    "$mydir"/FuturaImages

"$mydir"/../Build/FontRenderDiff \
    /Library/Fonts/Trattatello.ttf \
    "$mydir"/Trattatello.test.txt \
    "$mydir"/TrattatelloImages

