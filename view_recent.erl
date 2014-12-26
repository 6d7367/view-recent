-module(view_recent).
-export([start/0]).

-include_lib("xmerl/include/xmerl.hrl").
-define(RECENT_FILE, "~s/.local/share/recently-used.xbel").


start() ->
	init()
	.

init() ->
	RecentList = get_list(),

	GridColumns = [
		300, %% href
		150, %% type,
		100, %% count
		150, %% added,
		150  %% visited
	],
	WinWidth = lists:sum(GridColumns) + 20,
	WinHeight = 150,
	WinOpts = [{height, WinHeight}, {width, WinWidth}, {title, "Recent File List"}, {map, true}, {configure, true}],

	
	{ok, Counter, GridlineOpts} = prepare_gridline(RecentList, 1, []),
	GridOpts = [{bg, grey}, {columnwidths, GridColumns}, {width, WinWidth}, {height, WinHeight}, {rows, {1, Counter}}],

	Gs = gs:start(),
	Win = gs:create(window, Gs, WinOpts),
	Grid = gs:create(grid, Win, GridOpts),

	CreateGridLineFun = fun(Opts) -> gs:create(gridline, Grid, Opts) end,
	lists:foreach(CreateGridLineFun, GridlineOpts),
	
	loop(Win, Grid),
	gs:stop()
	.

loop(Win, Grid) ->
	receive
		{gs, Win, destroy, _Data, _Args} ->
			ok;
		{gs, _Obj, configure, _Data, [W,H|_]} ->
			gs:config(Grid, [{width, W}, {height, H}]),
			loop(Win, Grid);
		{gs, _Obj, _Event, _Data, _Args} -> 
			loop(Win, Grid)
	end
	.
		
%%% API

prepare_gridline([], Counter, Acc) -> {ok, Counter -1, Acc};
prepare_gridline([Item|Items], Counter, Acc) ->
	{href, Href}       = lists:keyfind(href, 1, Item),
	{type, Type}       = lists:keyfind(type, 1, Item),
	{count, Count}     = lists:keyfind(count, 1, Item),
	{added, Added}     = lists:keyfind(added, 1, Item),
	{visited, Visited} = lists:keyfind(visited, 1, Item),
	Opts = [{row, Counter}, {bg, white}, {fg, black},
		{text, {1, Href}},   %% href
		{text, {2, Type}},   %% type
		{text, {3, Count}},  %% count
		{text, {4, Added}},  %% added
		{text, {5, Visited}} %% visited
	],
	NewAcc = [Opts|Acc],
	prepare_gridline(Items, Counter+1, NewAcc)
	.
	

get_list() ->
	{ok, [HomeDir]} = init:get_argument(home),
	FilePath = io_lib:format(?RECENT_FILE, [HomeDir]),
	{XmlData, _M} = xmerl_scan:file(FilePath),
	RecentItems = prepare_list(XmlData#xmlElement.content, []),
	RecentItems
	.

prepare_list([], Acc) -> Acc;

prepare_list([Item|Items], Acc) ->
	NewAcc = case Item of
		#xmlElement{name=bookmark} -> 
			
			
			{ok, Info} = get_info(Item#xmlElement.content),
			{ok, Metadata} = get_metadata(Info#xmlElement.content),
			{ok, Mime} = get_mime(Metadata#xmlElement.content),
			{ok, Applications} = get_applications(Metadata#xmlElement.content),
			{ok, Application} = get_application(Applications#xmlElement.content),
			
			AvailableAttrs = [href, added, modified, visited, type, count],
			Attrs = prepare_attributes(AvailableAttrs, Item#xmlElement.attributes, []),
			[TypeAttr] = prepare_attributes(AvailableAttrs, Mime#xmlElement.attributes, []),
			[Count|_] = prepare_attributes(AvailableAttrs, Application#xmlElement.attributes, []),
			R = [TypeAttr, Count|Attrs],
			[R|Acc];
		_ -> Acc
	end,
	prepare_list(Items, NewAcc)
	.

prepare_attributes(_AvailableAttrs, [], Acc) -> Acc;
prepare_attributes(AvailableAttrs, [Attr|Attrs], Acc) ->
	AttrName = Attr#xmlAttribute.name,
	
	NewAcc = case lists:member(AttrName, AvailableAttrs) of
		true -> 
			AttrValue = Attr#xmlAttribute.value,
			NewValue = [{AttrName, AttrValue}|Acc],
			NewValue;
		_ -> Acc
	end,
	prepare_attributes(AvailableAttrs, Attrs, NewAcc)
	.

%% разобраться почему не срабатывает общий паттерн-матчинг

get_info([]) -> error;

get_info([Item|Items]) ->
	case Item of
		#xmlElement{name=info} ->
			{ok, Item};
		_ -> get_info(Items)
	end
	.

get_metadata([]) -> error;

get_metadata([Item|Items]) ->
	case Item of
		#xmlElement{name=metadata} ->
			{ok, Item};
		_ -> get_metadata(Items)
	end
	.

get_mime([]) -> error;

get_mime([Item|Items]) ->
	case Item of
		#xmlElement{name='mime:mime-type'} ->
			{ok, Item};
		_ -> get_mime(Items)
	end
	.

get_applications([]) -> error;

get_applications([Item|Items]) ->
	case Item of
		#xmlElement{name='bookmark:applications'} ->
			{ok, Item};
		_I -> get_applications(Items)
	end
	.

get_application([]) -> error;

get_application([Item|Items]) ->
	case Item of
		#xmlElement{name='bookmark:application'} ->
			{ok, Item};
		_ -> get_application(Items)
	end
	.