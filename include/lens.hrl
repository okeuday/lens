%   File   : lens
%   Author : Richard A. O'Keefe
%   Updated: Fri Nov 27 2015
%   Purpose: Implement Haskell-style Lenses for Erlang
%   SeeAlso: https://github.com/jlouis/erl-lenses

-compile({nowarn_unused_function, [
    % interface
    {lens_get,2}, {lens_put,3}, {lens_update,3},
    {lens_c,2}, {lens_c,3}, {lens_c,4}, {lens_c,5}, {lens_c,6},
    {lens_complete,2},
    {lens_id,0},
    {lens_hd,0}, {lens_tl,0}, {lens_index,1}, {lens_where,1}, {lens_all,1},
    {lens_gb_lookup,1}, % {lens_gb_tree,1},
    {lens_integer,0},
    {lens_tuple,1},
    {lens_pair_fst,0}, {lens_pair_snd,0},
    {lens_triple_fst,0}, {lens_triple_snd,0}, {lens_triple_thd,0}

    % private
  , {lens_nth,2},
    {lens_set_nth,3},
    {lens_update_nth,3},
    {lens_find,2},
    {lens_set_find,3},
    {lens_update_find,3},
    {lens_map2,3}

]}).

-compile({inline, [
    lens_get/2, lens_put/3, lens_update/3,
    lens_c/2, lens_c/3, lens_c/4, lens_c/5, lens_c/6,
    lens_hd/0, lens_tl/0, lens_index/1, lens_where/1,
    lens_tuple/1,
    lens_pair_fst/0, lens_pair_snd/0,
    lens_triple_fst/0, lens_triple_snd/0, lens_triple_thd/0
]}).

%   A lens is a triple of functions
%   { Get :: (A) -> B,  Put :: (A, B) -> A, Upd :: (A, (B) -> B) -> A. }.
%   They *should* satisfy the following laws:
%       Get(Put(A, B)) = B
%       Put(A, Get(A)) = A
%       Upd(A, Fun)    = Put(A, Fun(Get(A)))
%       Put(A, B)      = Upd(A, fun (_) -> B end)
%   and a meta-law:
%       No side effects except raising an exception for non-existent data.
%   The code below doesn't actually depend on these laws,
%   but if we expect lenses to act like field access and indexing
%   the laws had better be followed.

%   We can apply these operations in various ways to extract and
%   replace information, but we can also *compose* them.
%   See the df/2 example below, which composes 3 field selectors
%   to make something that can be got or put in what looks like one step.

lens_get({G,_,_}, X) -> G(X).

lens_put({_,P,_}, X, Y) -> P(X, Y).

lens_update({_,_,U}, X, F) -> U(X, F).

lens_complete(G, P) ->
    { G
    , P
    , fun (X, F) -> P(X, F(G(X))) end
    }.

%   id() is the identity lens.
%   I owe this to Jesper Louis Anderson, who wrote and published
%   a lens implementation for Erlang back in July 2012.
%   We expect that c(id(), L) = c(L, id()) = L.

lens_id() ->
    { fun (X)    -> X end
    , fun (_, Y) -> Y end
    , fun (X, F) -> F(X) end
    }.

%   get(hd(), X) = head(X)

lens_hd() ->
    { fun ([H|_])    -> H end
    , fun ([_|T], H) -> [H|T] end
    , fun ([H|T], F) -> [F(H)|T] end
    }.

%   get(tl(), X) = tail(X)

lens_tl() ->
    { fun ([_|T])    -> T end
    , fun ([H|_], T) -> [H|T] end
    , fun ([H|T], F) -> [H|F(T)] end
    }.

lens_nth(1, [H|_]) -> H;
lens_nth(N, [_|T]) when N > 1 ->
    lens_nth(N-1, T).

lens_set_nth(1, [_|T], X) -> [X|T];
lens_set_nth(N, [H|T], X) when N > 1 ->
    [H|lens_set_nth(N-1, T, X)].

lens_update_nth(1, [X|T], F) -> [F(X)|T];
lens_update_nth(N, [H|T], F) when N > 1 ->
    [H|lens_update_nth(N-1, T, F)].

%   get(index(N), L) = the Nth element of  L, 1-origin.
%   It is an error if there is no such element.

lens_index(N) ->
    { fun (Xs)    -> lens_nth(N, Xs) end
    , fun (Xs, Y) -> lens_set_nth(N, Xs, Y) end
    , fun (Xs, F) -> lens_update_nth(N, Xs, F) end
    }.

lens_find(P, [H|T]) ->
    case P(H)
      of true  -> H
       ; false -> lens_find(P, T)
    end.

lens_set_find(P, [H|T], X) ->
    case P(H)
      of true  -> [X|T]
       ; false -> [H|lens_set_find(P, T, X)]
    end.

lens_update_find(P, [H|T], F) ->
    case P(H)
      of true  -> [F(H)|T]
       ; false -> [H|lens_update_find(P, T, F)]
    end.       

%   get(where(P), L) is the first element X of L for which P(X).
%   It is an error if there is no such element.

lens_where(P) ->
    { fun (Xs)    -> lens_find(P, Xs) end
    , fun (Xs, Y) -> lens_set_find(P, Xs, Y) end
    , fun (Xs, F) -> lens_update_find(P, Xs, F) end
    }.

%   get(tuple(N), T) = element(N, T).
%   Its real intended use is tuple(#<record>.<field>).

lens_tuple(N) ->
    { fun (T)    -> element(N, T) end
    , fun (T, Y) -> setelement(N, T, Y) end
    , fun (T, F) -> setelement(N, T, F(element(N, T))) end
    }.


lens_pair_fst() ->
    { fun ({A,_})    -> A end
    , fun ({_,B}, A) -> {A,B} end
    , fun ({A,B}, F) -> {F(A),B} end
    }.

lens_pair_snd() ->
    { fun ({_,B})    -> B end
    , fun ({A,_}, B) -> {A,B} end
    , fun ({A,B}, F) -> {A,F(B)} end
    }.

lens_triple_fst() ->
    { fun ({A,_,_})    -> A end
    , fun ({_,B,C}, A) -> {A,B,C} end
    , fun ({A,B,C}, F) -> {F(A),B,C} end
    }.

lens_triple_snd() ->
    { fun ({_,B,_})    -> B end
    , fun ({A,_,C}, B) -> {A,B,C} end
    , fun ({A,B,C}, F) -> {A,F(B),C} end
    }.

lens_triple_thd() ->
    { fun ({_,_,C})    -> C end
    , fun ({A,B,_}, C) -> {A,B,C} end
    , fun ({A,B,C}, F) -> {A,B,F(C)} end
    }.

%   get(integer(), N) is N as a list of character codes.
%   This is a jeux d'esprit to point out that the information
%   we extract from a value does not have to be stored in it.

lens_integer() ->
    { fun (N) -> integer_to_list(N) end
    , fun (_, L) -> list_to_integer(L) end
    , fun (N, F) -> list_to_integer(F(integer_to_list(N))) end
    }.

%   We should also provide a lens for gb_trees.
%   This code is commented out because the updatef function is missing.
%
%lens_gb_tree(Key) ->
%   { fun (Tree)    -> gb_trees:get(Key, Tree) end
%   , fun (Tree, B) -> gb_trees:update(Key, Tree, B) end
%   , fun (Tree, F) -> gb_trees:updatef(Key, Tree, F) end
%   }/

%  lens_gb_lookup(K) -> lens(gb_tree(K,V), none | {value,V}).

lens_gb_lookup(Key) ->
    { fun (Tree) -> gb_trees:lookup(Key, Tree) end
    , fun (Tree, none)      -> gb_trees:delete_any(Key, Tree)
        ; (Tree, {value,V}) -> gb_trees:enter(Key, V, Tree)
      end
    , fun (Tree, F) ->
          case gb_trees:lookup(Key, Tree)
            of none -> Tree
             ; {value,V} -> gb_trees:update(Key, F(V), Tree)
          end
      end
    }.

%   c(Lens1, Lens2[, Lens3[, Lens4[, Lens5[, Lens6]]]])
%   compose 2 to 6 lens.  Composition is associative with
%   identity id, but not commutative.  These definitions
%   were generated by a program.

lens_c({G1,P1,U1}, {G2,P2,U2}) ->
    { fun (F0) -> G2(G1(F0)) end
    , fun (F0, R2) ->
        F1 = G1(F0),
        R1 = P2(F1, R2),
        P1(F0, R1)
      end
    , fun (F0, UF) ->
        U1(F0, fun (F1) -> 
          U2(F1, UF)
        end)
      end
    }.

lens_c({G1,P1,U1}, {G2,P2,U2}, {G3,P3,U3}) ->
    { fun (F0) -> G3(G2(G1(F0))) end
    , fun (F0, R3) ->
        F1 = G1(F0),
        F2 = G2(F1),
        R2 = P3(F2, R3),
        R1 = P2(F1, R2),
        P1(F0, R1)
      end
    , fun (F0, UF) ->
        U1(F0, fun (F1) -> 
          U2(F1, fun (F2) -> 
            U3(F2, UF)
          end)
        end)
      end
    }.

lens_c({G1,P1,U1}, {G2,P2,U2}, {G3,P3,U3}, {G4,P4,U4}) ->
    { fun (F0) -> G4(G3(G2(G1(F0)))) end
    , fun (F0, R4) ->
        F1 = G1(F0),
        F2 = G2(F1),
        F3 = G3(F2),
        R3 = P4(F3, R4),
        R2 = P3(F2, R3),
        R1 = P2(F1, R2),
        P1(F0, R1)
      end
    , fun (F0, UF) ->
        U1(F0, fun (F1) -> 
          U2(F1, fun (F2) -> 
            U3(F2, fun (F3) -> 
              U4(F3, UF)
            end)
          end)
        end)
      end
    }.

lens_c({G1,P1,U1}, {G2,P2,U2}, {G3,P3,U3}, {G4,P4,U4}, {G5,P5,U5}) ->
    { fun (F0) -> G5(G4(G3(G2(G1(F0))))) end
    , fun (F0, R5) ->
        F1 = G1(F0),
        F2 = G2(F1),
        F3 = G3(F2),
        F4 = G4(F3),
        R4 = P5(F4, R5),
        R3 = P4(F3, R4),
        R2 = P3(F2, R3),
        R1 = P2(F1, R2),
        P1(F0, R1)
      end
    , fun (F0, UF) ->
        U1(F0, fun (F1) -> 
          U2(F1, fun (F2) -> 
            U3(F2, fun (F3) -> 
              U4(F3, fun (F4) -> 
                U5(F4, UF)
              end)
            end)
          end)
        end)
      end
    }.

lens_c({G1,P1,U1}, {G2,P2,U2}, {G3,P3,U3}, {G4,P4,U4}, {G5,P5,U5}, {G6,P6,U6}) ->
    { fun (F0) -> G6(G5(G4(G3(G2(G1(F0)))))) end
    , fun (F0, R6) ->
        F1 = G1(F0),
        F2 = G2(F1),
        F3 = G3(F2),
        F4 = G4(F3),
        F5 = G5(F4),
        R5 = P6(F5, R6),
        R4 = P5(F4, R5),
        R3 = P4(F3, R4),
        R2 = P3(F2, R3),
        R1 = P2(F1, R2),
        P1(F0, R1)
      end
    , fun (F0, UF) ->
        U1(F0, fun (F1) -> 
          U2(F1, fun (F2) -> 
            U3(F2, fun (F3) -> 
              U4(F3, fun (F4) -> 
                U5(F4, fun (F5) -> 
                  U6(F5, UF)
                end)
              end)
            end)
          end)
        end)
      end
    }.

lens_map2(F, [X|Xs], [Y|Ys]) ->
    [F(X, Y) | lens_map2(F, Xs, Ys)];
lens_map2(_, [], []) ->
    [].

lens_all({G,P,U}) ->
    { fun (Xs) -> [G(X) || X <- Xs] end
    , fun (Xs, Ys) -> lens_map2(P, Xs, Ys) end
    , fun (Xs, F) -> [U(X, F) || X <- Xs] end
    }.

