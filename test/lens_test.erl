-module(lens_test).

-include("lens.hrl").
-include_lib("eunit/include/eunit.hrl").

%-----------------------------------------------------------------------
% Record fields #rec.field are integers but lenses would be nicer.
%-----------------------------------------------------------------------

-record(a, {p,q,r,s}).

hrl_df(R, Y) ->
  % R.p.q.r <- Y
    lens_put(lens_c(lens_tuple(#a.p), lens_tuple(#a.q), lens_tuple(#a.r)), R, Y).
erl_df(R, Y) ->
  % R.p.q.r <- Y
    lens:put(lens:c(lens:tuple(#a.p), lens:tuple(#a.q), lens:tuple(#a.r)), R, Y).

%-----------------------------------------------------------------------
% Examples.
%-----------------------------------------------------------------------

hrl_tc() ->
    lens_c(lens_pair_fst(), lens_triple_thd()).
erl_tc() ->
    lens:c(lens:pair_fst(), lens:triple_thd()).

hrl_td() ->
    {{1,2,3},4}.
erl_td() ->
    {{1,2,3},4}.


% 1> c(lens).
% {ok,lens}
% 2> lens:df({a,{a,p2,{a,p3,q3,r3,s3},r2,s2},q1,r1,s1}, 42).
% {a,{a,p2,{a,p3,q3,42,s3},r2,s2},q1,r1,s1}
% 3> lens:get(lens:tc(), lens:td()).
% 3
% 4> lens:put(lens:tc(), lens:td(), 5).
% {{1,2,5},4}
% 5> lens:update(lens:tc(), lens:td(), fun (N) -> 10*N-1 end).
% {{1,2,29},4}

example_hrl_test() ->
    {a,{a,p2,{a,p3,q3,42,s3},r2,s2},q1,r1,s1} =
        hrl_df({a,{a,p2,{a,p3,q3,r3,s3},r2,s2},q1,r1,s1}, 42),
    3 = lens_get(hrl_tc(), hrl_td()),
    {{1,2,5},4} = lens_put(hrl_tc(), hrl_td(), 5),
    {{1,2,29},4} = lens_update(hrl_tc(), hrl_td(), fun (N) -> 10*N-1 end),
    ok.

example_erl_test() ->
    {a,{a,p2,{a,p3,q3,42,s3},r2,s2},q1,r1,s1} =
        erl_df({a,{a,p2,{a,p3,q3,r3,s3},r2,s2},q1,r1,s1}, 42),
    3 = lens:get(erl_tc(), erl_td()),
    {{1,2,5},4} = lens:put(erl_tc(), erl_td(), 5),
    {{1,2,29},4} = lens:update(erl_tc(), erl_td(), fun (N) -> 10*N-1 end),
    ok.

%-----------------------------------------------------------------------
% Why we want cross-module inlining.
%-----------------------------------------------------------------------
%   consider
%   lens:update(lens:triple_snd(), Triple, fun (X) -> X+1 end).
%   (1) Expand lens:triple_snd/0 inline
%   lens:update({G,P,U}, Triple, fun (X) -> X + 1 end)
%      where G = fun ({_,B,_}) -> B end
%        and P = fun ({A,_,C}, B) -> {A,B,C} end
%        and U = fun ({A,B,C}, F) -> {A,F(B),C} end
%   (2) Expand lens:update/3 inline
%   U(Triple, f(X) -> X + 1 end
%      where U = fun ({A,B,C}, F) -> {A,F(B),C} end
%   (3) Expand U(X) inline
%   {A,B,C} = Triple, F = fun (X) -> X + 1 end, {A,F(B),C}
%   (4) expand F(X) inline
%   {A,B,C} = Triple, {A,B+1,C}
%   It's hard to improve this.

%-----------------------------------------------------------------------
% Lists.
%-----------------------------------------------------------------------
%
% We can index into a matrix represented as a list of lists:
% index2(Row, Col) -> c(list_lens(Row), list_lens(Col)).
% a(i,j) := x => put(index2(I,J), A, X).
% Easy to do, but the high cost of indexing into lists means
% this will never be a good idea.

