import std/os

switch("passL", "-lduckdb")

when defined(linux):
    switch("passL", "-L.")
elif defined(windows):
    switch("passL", "-L" & quoteShell("src/include"))

switch("passC", "-I.")
switch("define", "useCInt128=cunotequal,cnotequal,cuequal,cequal,cugreaterthanorequal,cgreaterthanorequal,cugreaterthan,cgreaterthan,culessthan,clessthan,culessthanorequal,clessthanorequal,cubitand,cbitand,cubitor,cbitor,cubitnot,cbitnot,cubitxor,cbitxor,cushl,cshl,cushr,cshr,cuplus,cplus,cuminus,cminus,cuminusunary,cminusunary,cumul64by64To128,cumul,cmul,cudivmod,cdivmod,cudiv,cdiv,cumod,cmod")
switch("define", "unittest2Compat=false")

