! Copyright (C) 2009 Daniel Ehrenberg
! See http://factorcode.org/license.txt for BSD license.
USING: sequences kernel splitting.monotonic accessors wrap grouping ;
IN: wrap.words

TUPLE: word key width break? ;
C: <word> word

<PRIVATE

: words-length ( words -- length )
    [ width>> ] map sum ;

: make-element ( whites blacks -- element )
    [ append ] [ [ words-length ] bi@ ] 2bi <element> ;
 
: ?first2 ( seq -- first/f second/f )
    [ 0 swap ?nth ]
    [ 1 swap ?nth ] bi ;

: split-words ( seq -- half-elements )
    [ [ break?>> ] bi@ = ] monotonic-split ;

: ?first-break ( seq -- newseq f/element )
    dup first first break?>>
    [ unclip-slice f swap make-element ]
    [ f ] if ;

: make-elements ( seq f/element -- elements )
    [ 2 <groups> [ ?first2 make-element ] map ] dip
    [ prefix ] when* ;

: words>elements ( seq -- newseq )
    split-words ?first-break make-elements ;

PRIVATE>

: wrap-words ( words line-max line-ideal -- lines )
    [ words>elements ] 2dip wrap [ concat ] map ;

