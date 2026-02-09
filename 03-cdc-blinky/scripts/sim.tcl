# simulation script
file mkdir sim_build
cd sim_build
puts "Compiling..."
exec xvlog -sv ../rtl/sync_2ff.sv ../rtl/gray_counter.sv ../rtl/async_fifo.sv ../tb/tb_async_fifo.sv >@ stdout

puts "Elaborating..."
exec xelab -debug typical -top tb_async_fifo -snapshot tb_async_fifo_snap >@ stdout

puts "Simulating..."
exec xsim tb_async_fifo_snap --runall >@ stdout
