defmodule Server.MessageReceiverTest do
use ExUnit.Case

    # @header <<"{here is the header must b 30}">>
    # @priority_code <<"Q">>
    # @agent_number <<"a">>
    # @message <<"{here is the message it must b 40 bytes}">>
      
    # test "it should extract relevant data from UDP packet" do
    #     packet = @header <> @priority_code <> @agent_number <> @message
    #     message = Server.MessageReceiver.parse_packet(packet)
    #     assert message
    #     assert message.priority_code == "Q"
    #     assert message.agent_number == "a"
    #     assert message.message == "{here is the message it must b 40 bytes}"
    # end

    # test "does MessagePack work" do
    #     msg = MessagePack.unpack!(<<147,01,02,03>>) #=> [1,2,3]
    #     assert msg = [1, 2, 3]
    # end

    # test  "simple binary pattern matching" do
    #     msg = Server.MessageReceiver.parse_packet(<<"a">>)
    #     assert msg.test == "a"
    #     # assert msg = 
    # end
end