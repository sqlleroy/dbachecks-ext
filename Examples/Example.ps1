$a = Invoke-DbcCheck -Tag DatabaseCollation -SqlInstance wpg1lsds02:7221 -PassThru
$t = $a.TestResult[-1].Parameters
Invoke-Command -ScriptBlock $t.Fix.Command -ArgumentList $t.Fix.Params