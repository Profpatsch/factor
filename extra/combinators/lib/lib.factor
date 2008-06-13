! Copyright (C) 2007, 2008 Slava Pestov, Chris Double,
!                          Doug Coleman, Eduardo Cavazos,
!                          Daniel Ehrenberg.
! See http://factorcode.org/license.txt for BSD license.
USING: kernel combinators fry namespaces quotations hashtables
sequences assocs arrays inference effects math math.ranges
arrays.lib shuffle macros continuations locals ;

IN: combinators.lib

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Generalized versions of core combinators
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MACRO: ndip ( quot n -- ) dup saver -rot restorer 3append ;

MACRO: nslip ( n -- ) dup saver [ call ] rot restorer 3append ;

: 4slip ( quot a b c d -- a b c d ) 4 nslip ; inline

MACRO: nkeep ( n -- )
  [ ] [ 1+ ] [ ] tri
  '[ [ , ndup ] dip , -nrot , nslip ] ;

: 4keep ( w x y z quot -- w x y z ) 4 nkeep ; inline 

MACRO: ncurry ( n -- ) [ curry ] n*quot ;

MACRO:: nwith ( quot n -- )
  [let | n' [ n 1+ ] |
    [ n' -nrot [ n' nrot quot call ] n ncurry ] ] ;

MACRO: napply ( n -- )
  2 [a,b]
  [ [ 1- ] [ ] bi
    '[ , ntuck , nslip ] ]
  map concat >quotation [ call ] append ;

: 3apply ( obj obj obj quot -- ) 3 napply ; inline

: 2with ( param1 param2 obj quot -- obj curry )
    with with ; inline

: 3with ( param1 param2 param3 obj quot -- obj curry )
    with with with ; inline

: with* ( obj assoc quot -- assoc curry )
    swapd [ [ -rot ] dip call ] 2curry ; inline

: 2with* ( obj1 obj2 assoc quot -- assoc curry )
    with* with* ; inline

: 3with* ( obj1 obj2 obj3 assoc quot -- assoc curry )
    with* with* with* ; inline

: assoc-each-with ( obj assoc quot -- )
    with* assoc-each ; inline

: assoc-map-with ( obj assoc quot -- assoc )
    with* assoc-map ; inline

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! short circuiting words
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: short-circuit ( quots quot default -- quot )
    1quotation -rot { } map>assoc <reversed> alist>quot ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MACRO: 0&& ( quots -- quot )
  [ '[ drop @ dup not ] [ drop f ] 2array ] map
  { [ t ] [ ] }                       suffix
  '[ f , cond ] ;

MACRO: 1&& ( quots -- quot )
  [ '[ drop dup @ dup not ] [ drop drop f ] 2array ] map
  { [ t ] [ nip ] }                                  suffix
  '[ f , cond ] ;

MACRO: 2&& ( quots -- quot )
  [ '[ drop 2dup @ dup not ] [ drop 2drop f ] 2array ] map
  { [ t ] [ 2nip ] }                                   suffix
  '[ f , cond ] ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MACRO: 0|| ( quots -- quot )
  [ '[ drop @ dup ] [ ] 2array ] map
  { [ drop t ] [ f ] } suffix
  '[ f , cond ] ;

MACRO: 1|| ( quots -- quot )
  [ '[ drop dup @ dup ] [ nip ] 2array ] map
  { [ drop drop t ] [ f ] }              suffix
  '[ f , cond ] ;

MACRO: 2|| ( quots -- quot )
  [ '[ drop 2dup @ dup ] [ 2nip ] 2array ] map
  { [ drop 2drop t ] [ f ] }               suffix
  '[ f , cond ] ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! ifte
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MACRO: preserving ( predicate -- quot )
    dup infer effect-in
    dup 1+
    '[ , , nkeep , nrot ] ;

MACRO: ifte ( quot quot quot -- )
    '[ , preserving , , if ] ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! switch
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MACRO: switch ( quot -- )
    [ [ [ preserving ] curry ] dip ] assoc-map
    [ cond ] curry ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

! Conceptual implementation:

! : pcall ( seq quots -- seq ) [ call ] 2map ;

MACRO: parallel-call ( quots -- )
    [ '[ [ unclip @ ] dip [ push ] keep ] ] map concat
    '[ V{ } clone @ nip >array ] ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! map-call and friends
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: (make-call-with) ( quots -- quot ) 
    [ [ keep ] curry ] map concat [ drop ] append ;

MACRO: map-call-with ( quots -- )
    [ (make-call-with) ] keep length [ narray ] curry compose ;

: (make-call-with2) ( quots -- quot )
    [ [ 2dup >r >r ] prepend [ r> r> ] append ] map concat
    [ 2drop ] append ;

MACRO: map-call-with2 ( quots -- )
    [
        [ [ 2dup >r >r ] prepend [ r> r> ] append ] map concat
        [ 2drop ] append    
    ] keep length [ narray ] curry append ;

MACRO: map-exec-with ( words -- )
    [ 1quotation ] map [ map-call-with ] curry ;

MACRO: construct-slots ( assoc tuple-class -- tuple ) 
    [ new ] curry swap [
        [ dip ] curry swap 1quotation [ keep ] curry compose
    ] { } assoc>map concat compose ;

: either ( object first second -- ? )
    >r keep swap [ r> drop ] [ r> call ] ?if ; inline

: 2quot-with ( obj seq quot1 quot2 -- seq quot1 quot2 )
    >r pick >r with r> r> swapd with ;

: or? ( obj quot1 quot2 -- ? )
    >r keep r> rot [ 2nip ] [ call ] if* ; inline

: and? ( obj quot1 quot2 -- ? )
    >r keep r> rot [ call ] [ 2drop f ] if ; inline

MACRO: multikeep ( word out-indexes -- ... )
    [
        dup >r [ \ npick \ >r 3array % ] each
        %
        r> [ drop \ r> , ] each
    ] [ ] make ;

: retry ( quot n -- )
    [ drop ] rot compose attempt-all ; inline

: do-while ( pred body tail -- )
    >r tuck 2slip r> while ;

: generate ( generator predicate -- obj )
    [ dup ] swap [ dup [ nip ] unless not ] 3compose
    swap [ ] do-while ;

MACRO: predicates ( seq -- quot/f )
    dup [ 1quotation [ drop ] prepend ] map
    >r [ [ dup ] prepend ] map r> zip [ drop f ] suffix
    [ cond ] curry ;
