rule SHIELD_EICAR_Test_File
{
    meta:
        description = "Detects the standard EICAR antivirus test string"
        severity = "test"
        source = "SHIELD baseline"

    strings:
        $eicar = "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"

    condition:
        $eicar
}
