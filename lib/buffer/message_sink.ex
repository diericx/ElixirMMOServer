defmodule MessageSink do
  def receive(message, time) do
    time_string = Timex.format!(time, "%Y-%m-%d %H:%M:%S", :strftime)
    IO.puts("#{time_string} #{message}")
  end
end