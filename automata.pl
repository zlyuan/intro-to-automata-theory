:- module('automata',
          [match_regex/2,
           match_suffix_regex/3,
           match_all_regex/3
           ]).

user:file_search_path(automata, './automata').

/** <module> High-level predicates for dealing with regular expressions

This module defines predicates for searching and replacing in strings
using regular expressions.

@see	https://github.com/wvxvw/intro-to-automata-theory
*/

:- meta_predicate
       match_regex(+, +),
       match_suffix_regex(+, +, -),
       match_all_regex(+, +, -).

:- use_module(automata(convert)).
:- use_module(library(pldoc)).
:- use_module(library(record)).
:- use_module(library(error)).

:- record match(str:list(integer), pos:integer).

:- dynamic match_str/2, match_pos/2, make_match/2.

step(From, Input, Transitions, Trn) :-
    format('step: ~w, ~w~n', [From, Input]),
    findall(T, (member(T, Transitions),
                trn_input(T, Input),
                trn_from(T, From)),
            [Trn | _]).

match_regex_helper([], _, Trn) :- !, trn_acc(Trn, true).
match_regex_helper([S | Ss], Diagram, Trn) :-
    char_code(C, S),
    trn_to(Trn, To),
    step(To, C, Diagram, Next),
    match_regex_helper(Ss, Diagram, Next).

suffix_regex_helper([], _, Trn, []) :- !, trn_acc(Trn, true).
suffix_regex_helper([S | Ss], Diagram, Trn, Suffix) :-
    char_code(C, S),
    trn_to(Trn, To),
    (
        step(To, C, Diagram, Next) ->
            suffix_regex_helper(Ss, Diagram, Next, Suffix),
            format('reading: ~w~n', [Suffix])
     ;
     trn_acc(Trn, true),
     Suffix = [S | Ss],
     format('else: ~w~n', [Suffix])
    ).
             
prepare_regex(Regex, Diagram) :-
    %% FIXME: regex_to_nfa should not backtrack!
    regex_to_nfa(Regex, Nfa), !,
    nfa_to_dfa(Nfa, Dfa),
    table_to_diagram(Dfa, UnsortedDiagram),
    sort(1, @=<, UnsortedDiagram, Diagram).

start_trn(Diagram, S, Trn) :-
    Diagram = [First | _],
    trn_from(First, F),
    char_code(C, S),
    findall(T, (member(T, Diagram),
                trn_from(T, F),
                trn_input(T, C)),
            [Trn | _]).

%%	match_regex(+Regex, +String) is det.
%
%	Evaluates to true if String is accepted by Regex.
%
%	@see	match_suffix_regex/3, match_all_regex/3

match_regex(Regex, [S | String]) :-
    prepare_regex(Regex, Diagram),
    start_trn(Diagram, S, Trn),
    match_regex_helper(String, Diagram, Trn).

%%	match_suffix_regex(+Regex, +String, -Suffix) is det.
%
%	Evaluates to true if Suffix is the remaining part of the String
%	not matched by Regex.
%
%	@see	match_regex/2, match_all_regex/3

match_suffix_regex(Regex, [S | String], Suffix) :-
    prepare_regex(Regex, Diagram),
    start_trn(Diagram, S, Trn),
    suffix_regex_helper(String, Diagram, Trn, Suffix).

match_all_helper(_, _, [], _) :- !, fail.
match_all_helper(N, Regex, String, Match) :-
    match_suffix_regex(Regex, String, Suffix),
    append(Str, Suffix, String),
    make_match([str(Str), pos(N)], Match)
    ;
    N1 is N + 1,
    String = [_ | S],
    match_all_helper(N1, Regex, S, Match).

%%	match_all_regex(+Regex, +String, -Match) is nondet.
%
%	Instantiates Match to all possible matches of Regex in String.
%
%	@see	match_regex/2, match_suffix_regex/3

match_all_regex(Regex, String, Match) :-
    match_all_helper(0, Regex, String, Match).
