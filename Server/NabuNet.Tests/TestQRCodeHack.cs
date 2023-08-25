using System;
using System.Text;

namespace NabuNet.Tests;

public class TestQRCodeHack
{

    [Test]
    public void MakeCode()
    {
        // The QR Code library works A-OK, but doesn't provide a direct access to the created code matrix.
        // We need that to enable "nabu on screen QR codes".

        var data = NabuNet.QRCodeHack.GenerateCode("https://nabu.atkelar.com/c/01234567890123456789012345678912", QRCodeCore.EccLevel.L);

        Assert.AreEqual(41, data.Count, "Expected QR code size mismatch!");
        // StringBuilder sb = new StringBuilder();
        // Console.WriteLine(data.Count);
        // for (int y = 0; y < data.Count; y++)
        // {
        //     for (int x = 0; x < data.Count; x++)
        //     {
        //         if (data[y][x])
        //             sb.Append("  ");
        //         else
        //             sb.Append("██");
        //     }
        //     sb.AppendLine();
        // }
        // Console.WriteLine(sb.ToString());
    }
}