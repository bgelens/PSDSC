#requires -Version 5
enum Ensure
{
    Absent
    Present
}

 

enum List
{
    First = 1
    Second = 2
    Last = 999

}


[DscResource()]
class Template
{
    [DscProperty(Key)]
    [String] $Name

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [String] $Info

    [DscProperty()]
    [List] $List

    [Template] Get()
    {
        return @{

        }
    }

    [Bool] Test()
    {
        return $true
    }

    [Void] Set()
    {

    }

    #Helper function to get the value from the enum
    [Int]SettingToValue([String] $Setting) 
    {
        return ([List]::$Setting).value__
    }

    #Helper function to get the key from the enum
    [String]ValueToSetting([int] $Index) 
    {
        return [List].GetEnumName($Index)
    }
}