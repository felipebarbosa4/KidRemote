<#
Goal: Reject KR-003 PowerShell variable declarations or writes that collide with automatic/read-only names.
Context: A runner-v3 assignment to script-scoped Host failed before its protected execution block.
Constraints: Static source/bundle inspection only; automatic-variable reads and the conventional null-output discard are allowed.
Done when: Every PowerShell payload parses and no reserved name is used as a parameter, assignment target, loop variable, increment target or variable-provider mutation target.
#>
param([string]$ScanRoot=$PSScriptRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
function Get-UnqualifiedVariableName($VariableNode){
    $path=[string]$VariableNode.VariablePath.UserPath
    $separator=$path.LastIndexOf(':')
    if($separator -ge 0){return $path.Substring($separator+1)}
    return $path
}

$reservedNames=@('Host','Error','Args','Input','Matches','PID','PSVersionTable','Home','PSScriptRoot','MyInvocation','LASTEXITCODE','true','false','null')
$mutationCommands=@('Set-Variable','New-Variable','Clear-Variable','Remove-Variable','sv','nv','cv','rv','Set-Item','New-Item','si','ni')
$findings=New-Object Collections.Generic.List[string]
$root=(Resolve-Path -LiteralPath $ScanRoot).Path
$files=@(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {$_.Extension -in @('.ps1','.psm1','.psd1')})
Assert-Equal ($files.Count -gt 0) $true

foreach($file in $files){
    $lexerTokens=$null;$parseIssues=$null
    $tree=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$lexerTokens,[ref]$parseIssues)
    if($parseIssues.Count){$findings.Add(($file.FullName+':PARSE_ERROR'))}

    foreach($variable in $tree.FindAll({param($node)$node -is [Management.Automation.Language.VariableExpressionAst]},$true)){
        if((Get-UnqualifiedVariableName $variable) -ieq 'Host'){$findings.Add(($file.FullName+':FORBIDDEN_HOST_REFERENCE:'+ $variable.Extent.StartLineNumber))}
    }

    foreach($parameter in $tree.FindAll({param($node)$node -is [Management.Automation.Language.ParameterAst]},$true)){
        $name=Get-UnqualifiedVariableName $parameter.Name
        if($reservedNames -icontains $name){$findings.Add(($file.FullName+':PARAMETER:'+$name+':'+$parameter.Extent.StartLineNumber))}
    }
    foreach($assignment in $tree.FindAll({param($node)$node -is [Management.Automation.Language.AssignmentStatementAst]},$true)){
        foreach($variable in $assignment.Left.FindAll({param($node)$node -is [Management.Automation.Language.VariableExpressionAst] -and $node.Extent.StartOffset -eq $assignment.Left.Extent.StartOffset},$true)){
            $name=Get-UnqualifiedVariableName $variable
            if($reservedNames -icontains $name){
                if($name -ieq 'null' -and $assignment.Left.Extent.Text -ieq '$null'){continue}
                $findings.Add(($file.FullName+':ASSIGNMENT:'+$name+':'+$variable.Extent.StartLineNumber))
            }
        }
    }
    foreach($loop in $tree.FindAll({param($node)$node -is [Management.Automation.Language.ForEachStatementAst]},$true)){
        $name=Get-UnqualifiedVariableName $loop.Variable
        if($reservedNames -icontains $name){$findings.Add(($file.FullName+':LOOP_VARIABLE:'+$name+':'+$loop.Variable.Extent.StartLineNumber))}
    }
    foreach($unary in $tree.FindAll({param($node)$node -is [Management.Automation.Language.UnaryExpressionAst]},$true)){
        if($unary.TokenKind -notin @('PostfixPlusPlus','PostfixMinusMinus','PlusPlus','MinusMinus')){continue}
        foreach($variable in $unary.Child.FindAll({param($node)$node -is [Management.Automation.Language.VariableExpressionAst]},$true)){
            $name=Get-UnqualifiedVariableName $variable
            if($reservedNames -icontains $name){$findings.Add(($file.FullName+':UNARY_WRITE:'+$name+':'+$variable.Extent.StartLineNumber))}
        }
    }
    foreach($command in $tree.FindAll({param($node)$node -is [Management.Automation.Language.CommandAst]},$true)){
        $commandName=$command.GetCommandName()
        if($mutationCommands -inotcontains $commandName){continue}
        foreach($element in @($command.CommandElements | Select-Object -Skip 1)){
            $value=$(if($element -is [Management.Automation.Language.StringConstantExpressionAst]){$element.Value}else{$element.Extent.Text.Trim([char[]]@([char]39,[char]34))})
            if($value -imatch '^variable:(.+)$'){$value=$Matches[1]}
            if($reservedNames -icontains $value){$findings.Add(($file.FullName+':VARIABLE_PROVIDER_WRITE:'+$value+':'+$element.Extent.StartLineNumber))}
        }
    }
}

if($findings.Count){throw ('Reserved PowerShell variable collision(s): '+($findings -join '; '))}
Write-Host ($script:Checks.ToString()+' PowerShell reserved-variable audit assertions passed across '+$files.Count+' files.')
