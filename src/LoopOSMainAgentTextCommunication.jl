module LoopOSMainAgentTextCommunication

using ZMQ
using LoopOS: InputPeripheral, OutputPeripheral, listen, @whiletrue
import Base: take!, put!

const AGENTGROUP = Dict{String,String}()

const CONTEXT = ZMQ.context()
const ROUTERSOCKET = Socket(CONTEXT, ROUTER)
const PUBSOCKET = Socket(CONTEXT, PUB)

function init(routerlocation, publocation)
    bind(ROUTERSOCKET, routerlocation)
    bind(PUBSOCKET, publocation)
    listen(RECEIVEMESSAGE)
    @whiletrue begin
        frames = recv_multipart(ROUTERSOCKET)
        to = String(frames[1])
        from = String(frames[2])
        haskey(AGENTGROUP, from) || continue
        message = String(frames[3])
        if to == Sys.username()
            put!(RECEIVEMESSAGE, message)
        elseif to == "group"
            group = AGENTGROUP[from]
            send_multipart(PUBSOCKET, [group, from, message])
        elseif AGENTGROUP[from] == get(AGENTGROUP, to, "")
            send_multipart(ROUTERSOCKET, [to, from, message])
        end
    end
end

send(socket, message, to) = send_multipart(socket, [to, Sys.username(), message])
struct DirectMessage <: OutputPeripheral end
put!(::DirectMessage, message::String, to::String) = send(ROUTERSOCKET, message, to)
struct GroupMessage <: OutputPeripheral end
put!(::GroupMessage, message::String, to::String="∀") = send(PUBSOCKET, message, to)
struct ReceiveMessage <: InputPeripheral
    channel::Channel{String}
end
take!(a::ReceiveMessage) = take!(a.channel)
put!(a::ReceiveMessage, message) = put!(a.channel, message)
const RECEIVEMESSAGE = ReceiveMessage(Channel{String}(Inf))

end
