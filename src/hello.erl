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
        WebSocketOwner = spawn(fun() -> active_websocket_owner() end),
        {websocket, WebSocketOwner, active}
    end.

active_websocket_owner() ->
    % io:format("websocket_owner: ~p~n", [self()]),
    receive
        {ok, WebSocket} ->
            io:format("websocket ok"),
            yaws_api:websocket_setopts(WebSocket, [{active, true}]),            
            echo_server(WebSocket);    
        _ -> io:format("websocket_owner"),         
             ok
    end.

websocket_owner() ->
    % io:format("websocket_owner: ~p~n", [self()]),
    receive
    {ok, WebSocket} ->
        io:format("websocket ok"),
        %% This is how we read messages (plural!!) from websockets on passive mode
        case yaws_api:websocket_receive(WebSocket) of
        {error,closed} ->
            io:format("The websocket got disconnected right from the start. "
                  "This wasn't supposed to happen!!~n");
        {ok, Messages} ->
            case Messages of
            [<<"hekas">>] ->
                yaws_api:websocket_setopts(WebSocket, [{active, true}]),
                echo_server(WebSocket);
            Other ->
                io:format("websocket_owner got: ~p. Terminating~n", [Other])
            end
        end;
    _ -> io:format("websocket_owner"), 
         ok
    end.

echo_server(WebSocket) ->
    receive
        {tcp, WebSocket, DataFrame} ->      
            Data = yaws_api:websocket_unframe_data(DataFrame),        
            io:format("Got data from Websocket: ~p~n", [Data]),
            yaws_api:websocket_send(WebSocket, Data), 
            echo_server(WebSocket);
    
        {tcp_closed, WebSocket} ->        
            io:format("Websocket closed. Terminating echo_server...~n");
    
        Any ->        
            io:format("echo_server received msg:~p~n", [Any]),        
            echo_server(WebSocket)    
    end.

%%
%% Local Functions
%%

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


