%% Author: fatso
%% Created: Aug 29, 2011
%% Description: TODO: Add description to hello
-module(hello).

%%
%% Include files
%%
-include("/usr/local/lib/yaws/include/yaws_api.hrl").
 
%%
%% Exported Functions 
%%
-export([out/1]).
 
%%
%% API Functions
%%
  
out(A) ->
    io:format("connection: ~p~n", [A]),
    
    case get_upgrade_header(A#arg.headers) of 
        undefined ->
            {content, "text/plain", "You're not a web sockets client! Go00 away!"};

        "WebSocket" ->
            WebSocketOwner = spawn(fun() -> websocket_owner() end),
            {websocket, WebSocketOwner, passive}
    end.

%%
%% Local Functions
%%

active_websocket_owner() ->
    io:format("websocket_owner: ~p~n", [self()]),
    receive
        {ok, WebSocket} ->
            io:format("websocket ok"),
            
            % strangely we have to set websockets opts again even if active was returned in out/1
            yaws_api:websocket_setopts(WebSocket, [{active, true}]),
            
            Nick = "testnick",
            chat_server ! {login, {self(), Nick}},
            echo_server(WebSocket, Nick);    
        
        _ -> io:format("websocket_owner"),         
             ok
    end.

websocket_owner() ->
    io:format("websocket_owner: ~p~n", [self()]),
    receive
        {ok, WebSocket} ->
            io:format("websocket ok"),
            %% This is how we read messages (plural!!) from websockets on passive mode
            case yaws_api:websocket_receive(WebSocket) of
        {error,closed} ->
            io:format("The websocket got disconnected right from the start. "
                  "This wasn't supposed to happen!!~n");
        {ok, Nick} ->
            chat_server ! {login, {self(), Nick}},        
            yaws_api:websocket_setopts(WebSocket, [{active, true}]),
            echo_server(WebSocket, Nick)
        end;
    _ -> io:format("websocket_owner"), 
         ok
    end.

echo_server(WebSocket, Nick) ->
    receive
        {tcp, WebSocket, DataFrame} ->      
            Data = yaws_api:websocket_unframe_data(DataFrame),        
            io:format("Got data from Websocket: ~p~n", [Data]),            
            
            %%% this would be echo here.
            %% yaws_api:websocket_send(WebSocket, Data),
            
            chat_server ! {msg, Data},            
            echo_server(WebSocket, Nick);
    
        {tcp_closed, WebSocket} ->                    
            io:format("Websocket closed. Terminating echo_server...~n"),
            chat_server ! {logout, {self(), Nick}};
    
        {channelMsg, Msg} -> 
            yaws_api:websocket_send(WebSocket, Msg),
            echo_server(WebSocket, Nick);
    
        Any ->        
            io:format("echo_server received msg:~p~n", [Any]),        
            echo_server(WebSocket, Nick)    
    end.

get_upgrade_header(#headers{other=L}) ->
    lists:foldl(fun({http_header,_,K0,_,V}, undefined) ->
                        K = case is_atom(K0) of
                                true ->
                                    atom_to_list(K0);
                                false ->
                                    K0
                            end,
                        case string:to_lower(K) of
                            "upgrade" ->
                                V;
                            _ ->
                                undefined
                        end;
                   (_, Acc) ->
                        Acc
                end, undefined, L).


