using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;

namespace NabuNet
{
    public class QRCodeHack
    {
        // The QR Code library works A-OK, but doesn't provide a direct access to the created code matrix.
        // We need that to enable "nabu on screen QR codes".

        private static Type _Generator;
        private static MethodInfo _CreateQRCode;
        private static PropertyInfo? _MatrixProperty;

        static QRCodeHack()
        {
            _Generator = typeof(QRCodeCore.SvgQRCode).Assembly.GetType("QRCodeCore.QRCodeGenerator");
            _CreateQRCode = _Generator.GetMethod("CreateQRCode");
            _MatrixProperty = typeof(QRCodeCore.SvgQRCode).Assembly.GetType("QRCodeCore.QRCodeMatrix").GetProperty("ModuleMatrix");
        }

        public static List<BitArray> GenerateCode(string text, QRCodeCore.EccLevel eccLevel = QRCodeCore.EccLevel.M)
        {
            var inst = Activator.CreateInstance(_Generator);
            var output = _CreateQRCode.Invoke(inst, new object[] { text, eccLevel, false });

            Console.WriteLine(output.GetType().FullName);
            // matrix.ModuleMatrix.Count  -> # of modules.
            // public List<BitArray> ModuleMatrix 

            return (List<BitArray>)_MatrixProperty.GetValue(output);
        }
    }

}