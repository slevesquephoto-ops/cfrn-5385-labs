#requires -version 5.1
<#
ABData-Macro.ps1 - Macro Basic de numérotation automatique dans le modèle Facture-AB.ott (R6-E).
Chargé (dot-source) par tools\New-ABData.ps1.

À la création d'une facture à partir du modèle (événement « Créer un document »), la
macro remplace « 2026-0___ » par un numéro et « ____________ » (date) par la date du jour.
Bloquée par la sécurité des macros « Très élevé » si le dossier n'est pas un
emplacement de confiance.
#>

if (-not ('ABNative.OdfZip' -as [type])) {
    # Écrivain ZIP minimal pour ODF : « mimetype » stocké (méthode 0) en premier, le reste en
    # Deflate. Le ZipArchive du .NET Framework compresse toujours (méthode 8), même en
    # NoCompression : LibreOffice juge alors le document corrompu (vu en VM).
    Add-Type -Language CSharp -ReferencedAssemblies System.IO.Compression -TypeDefinition @'
using System; using System.IO; using System.IO.Compression; using System.Text;
namespace ABNative {
public static class OdfZip {
    static readonly uint[] Table = MakeTable();
    static uint[] MakeTable() { var t = new uint[256]; for (uint i = 0; i < 256; i++) { uint c = i; for (int k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320u ^ (c >> 1) : c >> 1; t[i] = c; } return t; }
    static uint Crc(byte[] d) { uint c = 0xFFFFFFFF; foreach (byte b in d) c = Table[(c ^ b) & 0xFF] ^ (c >> 8); return ~c; }
    public static void Write(string path, string[] names, byte[][] datas) {
        using (var fs = new FileStream(path, FileMode.Create)) using (var w = new BinaryWriter(fs)) {
            var central = new MemoryStream(); var cw = new BinaryWriter(central);
            for (int i = 0; i < names.Length; i++) {
                byte[] name = Encoding.UTF8.GetBytes(names[i]); byte[] data = datas[i] ?? new byte[0];
                bool store = names[i] == "mimetype" || data.Length == 0;
                byte[] comp = data; ushort method = 0;
                if (!store) { var ms = new MemoryStream(); using (var ds = new DeflateStream(ms, CompressionLevel.Optimal, true)) ds.Write(data, 0, data.Length); comp = ms.ToArray(); method = 8; }
                uint crc = Crc(data); uint offset = (uint)fs.Position; ushort flags = (ushort)(names[i] == "mimetype" ? 0 : 0x0800);
                w.Write(0x04034b50u); w.Write((ushort)20); w.Write(flags); w.Write(method); w.Write((ushort)0); w.Write((ushort)0x21);
                w.Write(crc); w.Write((uint)comp.Length); w.Write((uint)data.Length); w.Write((ushort)name.Length); w.Write((ushort)0); w.Write(name); w.Write(comp);
                cw.Write(0x02014b50u); cw.Write((ushort)20); cw.Write((ushort)20); cw.Write(flags); cw.Write(method); cw.Write((ushort)0); cw.Write((ushort)0x21);
                cw.Write(crc); cw.Write((uint)comp.Length); cw.Write((uint)data.Length); cw.Write((ushort)name.Length); cw.Write((ushort)0); cw.Write((ushort)0);
                cw.Write((ushort)0); cw.Write((ushort)0); cw.Write((uint)0); cw.Write(offset); cw.Write(name);
            }
            uint cdOffset = (uint)fs.Position; byte[] cd = central.ToArray(); w.Write(cd);
            w.Write(0x06054b50u); w.Write((ushort)0); w.Write((ushort)0); w.Write((ushort)names.Length); w.Write((ushort)names.Length); w.Write((uint)cd.Length); w.Write(cdOffset); w.Write((ushort)0);
        }
    }
}
}
'@
}

function Add-ABTemplateMacro {
    param([Parameter(Mandatory)][string]$Path)
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $basic = @'
Sub NumeroterFacture
    Dim oDoc As Object, oSearch As Object, oFound As Object
    oDoc = ThisComponent
    oSearch = oDoc.createSearchDescriptor()
    oSearch.SearchString = "2026-0___"
    oFound = oDoc.findFirst(oSearch)
    If Not IsNull(oFound) Then oFound.setString("2026-0" &amp; Format(143 + DateDiff("d", DateSerial(2026, 9, 28), Date()), "000"))
    oSearch.SearchString = "____________"
    oFound = oDoc.findFirst(oSearch)
    If Not IsNull(oFound) Then oFound.setString(Format(Date(), "yyyy-mm-dd"))
End Sub
'@
    $files = [ordered]@{
        'Basic/script-lc.xml'              = @'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE library:libraries PUBLIC "-//OpenOffice.org//DTD OfficeDocument 1.0//EN" "libraries.dtd">
<library:libraries xmlns:library="http://openoffice.org/2000/library" xmlns:xlink="http://www.w3.org/1999/xlink">
 <library:library library:name="Standard" library:link="false"/>
</library:libraries>
'@
        'Basic/Standard/script-lb.xml'     = @'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE library:library PUBLIC "-//OpenOffice.org//DTD OfficeDocument 1.0//EN" "library.dtd">
<library:library xmlns:library="http://openoffice.org/2000/library" library:name="Standard" library:readonly="false" library:passwordprotected="false">
 <library:element library:name="Numerotation"/>
</library:library>
'@
        'Basic/Standard/Numerotation.xml' = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<!DOCTYPE script:module PUBLIC `"-//OpenOffice.org//DTD OfficeDocument 1.0//EN`" `"module.dtd`">`n<script:module xmlns:script=`"http://openoffice.org/2000/script`" script:name=`"Numerotation`" script:language=`"StarBasic`" script:moduleType=`"normal`">$basic</script:module>"
    }
    $utf8 = New-Object Text.UTF8Encoding($false)
    # Lecture de toutes les entrées, puis archive RECONSTRUITE : ODF exige « mimetype » en
    # premier et NON compressé (le mode Update de .NET le recompresse : fichier « corrompu »
    # pour LibreOffice, vu en VM).
    $entries = [ordered]@{}
    $src = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($e in $src.Entries) {
            if ($e.FullName.EndsWith('/')) { $entries[$e.FullName] = $null; continue }
            $ms = New-Object IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close()
            $entries[$e.FullName] = $ms.ToArray()
        }
    } finally { $src.Dispose() }
    $text = { param($name) $utf8.GetString($entries[$name]) }
    # Événement « Créer un document » (OnNew) -> macro du document
    $content = & $text 'content.xml'
    $listener = '<office:scripts><office:event-listeners><script:event-listener script:language="ooo:script" script:event-name="office:new" xlink:href="vnd.sun.star.script:Standard.Numerotation.NumeroterFacture?language=Basic&amp;location=document" xlink:type="simple"/></office:event-listeners></office:scripts>'
    if ($content -notmatch 'script:event-name="office:new"') {
        if ($content -notmatch '<office:scripts/>') { throw 'content.xml : <office:scripts/> introuvable.' }
        $entries['content.xml'] = $utf8.GetBytes($content.Replace('<office:scripts/>', $listener))
    }
    $manifest = & $text 'META-INF/manifest.xml'
    if ($manifest -notmatch 'Basic/script-lc.xml') {
        $add = ($files.Keys | ForEach-Object { " <manifest:file-entry manifest:full-path=`"$_`" manifest:media-type=`"text/xml`"/>" }) -join "`n"
        $entries['META-INF/manifest.xml'] = $utf8.GetBytes($manifest.Replace('</manifest:manifest>', "$add`n</manifest:manifest>"))
    }
    foreach ($k in $files.Keys) { $entries[$k] = $utf8.GetBytes($files[$k]) }
    $order = @('mimetype') + @($entries.Keys | Where-Object { $_ -ne 'mimetype' })
    $datas = New-Object 'byte[][]' $order.Count
    for ($i = 0; $i -lt $order.Count; $i++) { $datas[$i] = [byte[]]$entries[$order[$i]] }
    $tmp = "$Path.tmp"
    [ABNative.OdfZip]::Write($tmp, [string[]]$order, $datas)
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}
