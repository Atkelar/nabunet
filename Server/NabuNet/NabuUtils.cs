using System;
// some helper functions to interact with the core NABU PC code.


namespace NabuNet
{
    public static class NabuUtils
    {
        // compute the 5-digit channel code based on the 4-digit input (0-0xFFFF)
        public static string ChannelCodeFromNumber(int code)
        {
            if (code < 0 || code > 0xFFFF)
                throw new ArgumentOutOfRangeException(nameof(code), code, "Channel code must be 0x0000 to 0xFFFF!");
            // the following code is replicating the original assembler version step by step
            // and could thus use some optimization here...
            string rawCode = code.ToString("X4");   // start off with 4-digit hex in UPPER case.
            var c = (byte)0;
            for (int i = 0; i < 4; i++)
            {
                var b = (byte)(4 - i);    // register b counts 4 to zero
                var a = (byte)int.Parse(rawCode.Substring(i, 1), System.Globalization.NumberStyles.HexNumber);
                if ((b & 1) != 0)
                {
                    a *= 2;
                    if ((a & 0x10) != 0)
                    {
                        a &= 0xEF;
                        a++;
                    }
                }
                c += a;
            }
            return string.Format("{0}{1}", rawCode, (c & 0xF).ToString("X"));
        }
    }

}