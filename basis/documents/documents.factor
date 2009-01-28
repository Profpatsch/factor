! Copyright (C) 2006, 2009 Slava Pestov
! See http://factorcode.org/license.txt for BSD license.
USING: accessors arrays io kernel math models namespaces make
sequences strings splitting combinators unicode.categories
math.order math.ranges fry locals ;
IN: documents

: +col ( loc n -- newloc ) [ first2 ] dip + 2array ;

: +line ( loc n -- newloc ) [ first2 swap ] dip + swap 2array ;

: =col ( n loc -- newloc ) first swap 2array ;

: =line ( n loc -- newloc ) second 2array ;

: lines-equal? ( loc1 loc2 -- ? ) [ first ] bi@ number= ;

TUPLE: edit old-string new-string from old-to new-to ;

C: <edit> edit

TUPLE: document < model locs undos redos inside-undo? ;

: clear-undo ( document -- )
    V{ } clone >>undos
    V{ } clone >>redos
    drop ;

: <document> ( -- document )
    V{ "" } clone document new-model
    V{ } clone >>locs
    dup clear-undo ;

: add-loc ( loc document -- ) locs>> push ;

: remove-loc ( loc document -- ) locs>> delete ;

: update-locs ( loc document -- )
    locs>> [ set-model ] with each ;

: doc-line ( n document -- string ) value>> nth ;

: line-end ( line# document -- loc )
    [ drop ] [ doc-line length ] 2bi 2array ;

: doc-lines ( from to document -- slice )
    [ 1+ ] [ value>> ] bi* <slice> ;

: start-on-line ( document from line# -- n1 )
    [ dup first ] dip = [ nip second ] [ 2drop 0 ] if ;

: end-on-line ( document to line# -- n2 )
    over first over = [
        drop second nip
    ] [
        nip swap doc-line length
    ] if ;

: each-line ( from to quot -- )
    2over = [
        3drop
    ] [
        [ [ first ] bi@ [a,b] ] dip each
    ] if ; inline

: start/end-on-line ( from to line# -- n1 n2 )
    tuck
    [ [ document get ] 2dip start-on-line ]
    [ [ document get ] 2dip end-on-line ]
    2bi* ;

: last-line# ( document -- line )
    value>> length 1- ;

CONSTANT: doc-start { 0 0 }

: doc-end ( document -- loc )
    [ last-line# ] keep line-end ;

<PRIVATE

: (doc-range) ( from to line# -- )
    [ start/end-on-line ] keep document get doc-line <slice> , ;

: text+loc ( lines loc -- loc )
    over [
        over length 1 = [
            nip first2
        ] [
            first swap length 1- + 0
        ] if
    ] dip peek length + 2array ;

: prepend-first ( str seq -- )
    0 swap [ append ] change-nth ;

: append-last ( str seq -- )
    [ length 1- ] keep [ prepend ] change-nth ;

: loc-col/str ( loc document -- str col )
    [ first2 swap ] dip nth swap ;

: prepare-insert ( new-lines from to lines -- new-lines )
    tuck [ loc-col/str head-slice ] [ loc-col/str tail-slice ] 2bi*
    pick append-last over prepend-first ;

: (set-doc-range) ( new-lines from to lines -- )
    [ prepare-insert ] 3keep
    [ [ first ] bi@ 1+ ] dip
    replace-slice ;

: entire-doc ( document -- start end document )
    [ [ doc-start ] dip doc-end ] keep ;

: with-undo ( document quot: ( document -- ) -- )
    [ t >>inside-undo? ] dip keep f >>inside-undo? drop ; inline

PRIVATE>

: doc-range ( from to document -- string )
    [
        document set 2dup [
            [ 2dup ] dip (doc-range)
        ] each-line 2drop
    ] { } make "\n" join ;

: add-undo ( edit document -- )
    dup inside-undo?>> [ 2drop ] [
        [ undos>> push ] keep
        redos>> delete-all
    ] if ;

:: set-doc-range ( string from to document -- )
    string string-lines :> new-lines
    new-lines from text+loc :> new-to
    from to document doc-range :> old-string
    old-string string from to new-to <edit> document add-undo
    new-lines from to document value>> (set-doc-range)
    document notify-connections
    new-to document update-locs ;

: change-doc-range ( from to document quot -- )
    '[ doc-range @ ] 3keep set-doc-range ; inline

: remove-doc-range ( from to document -- )
    [ "" ] 3dip set-doc-range ;

: validate-line ( line document -- line )
    last-line# min 0 max ;

: validate-col ( col line document -- col )
    doc-line length min 0 max ;

: line-end? ( loc document -- ? )
    [ first2 swap ] dip doc-line length = ;

: validate-loc ( loc document -- newloc )
    2dup [ first ] [ value>> length ] bi* >= [
        nip doc-end
    ] [
        over first 0 < [
            2drop { 0 0 }
        ] [
            [ first2 swap tuck ] dip validate-col 2array
        ] if
    ] if ;

: doc-string ( document -- str )
    entire-doc doc-range ;

: set-doc-string ( string document -- )
    entire-doc set-doc-range ;

: clear-doc ( document -- )
    [ "" ] dip set-doc-string ;

<PRIVATE

: undo/redo-edit ( edit document string-quot to-quot -- )
    '[ [ _ [ from>> ] _ tri ] dip set-doc-range ] with-undo ; inline

: undo-edit ( edit document -- )
    [ old-string>> ] [ new-to>> ] undo/redo-edit ;

: redo-edit ( edit document -- )
    [ new-string>> ] [ old-to>> ] undo/redo-edit ;

: undo/redo ( document source-quot dest-quot do-quot -- )
    [ dupd call [ drop ] ] 2dip
    '[ pop swap [ @ push ] _ 2bi ] if-empty ; inline

PRIVATE>

: undo ( document -- )
    [ undos>> ] [ redos>> ] [ undo-edit ] undo/redo ;

: redo ( document -- )
    [ redos>> ] [ undos>> ] [ redo-edit ] undo/redo ;