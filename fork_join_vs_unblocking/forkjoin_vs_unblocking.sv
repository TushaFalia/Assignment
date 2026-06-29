module forkjoin_vs_unblocking ();

int a =0;
int b=5;
int sum;

initial begin
    fork
        $display("[%0t] Execution of A" ,$time);
        $display("[%0t] Execution of B",$time); 
join_none

end

initial begin
    $display("[%0t] a =", a,$time);
    $display ("[%0t] b=", b,$time);
    a<=b;
    b<=a; 
    $display("[%0t] a =", a,$time);
    $display ("[%0t] b=", b,$time);
    #5
    $display("[%0t] a =", a,$time);
    $display ("[%0t] b=", b,$time);
end

endmodule
//xvlog -sv forkjoin_vs_unblocking.sv
//xelab forkjoin_vs_unblocking -s simulation -debug all
// xsim simulation -runall