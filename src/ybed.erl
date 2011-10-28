-module(ybed).
-compile(export_all).
-include("/usr/local/lib/yaws/include/yaws_api.hrl").

%% DOCROOT can be absolute Path. as well.
-define(DOCROOT, "./na/www").

start() ->
    {ok, spawn(?MODULE, run, [])}.

run() ->
    Id = "embedded",
    Docroot = ?DOCROOT,
    GconfList = [{id, Id}],    
    SconfList = [{port, 7000},
                 {listen, {0,0,0,0}},
                 {docroot, Docroot},
                 {appmods, [{"/chat", hello}]}],
    {ok, SCList, GC, ChildSpecs} = yaws_api:embedded_start_conf(Docroot, SconfList, GconfList, Id),
    [supervisor:start_child(ybed_sup, Ch) || Ch <- ChildSpecs],
    yaws_api:setconf(GC, SCList),
    {ok, self()}.