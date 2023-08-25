using System;
using System.Collections.Generic;
using ICSharpCode.SharpZipLib.Zip;
using NabuNet.Models;

namespace NabuNet
{

    public class AboutPageModel
    {
        public string Version { get; set; }

        public IEnumerable<Tuple<string, IEnumerable<LibraryInfo>>> Libraries { get; set; }

        public BaseArticle? Imprint { get; set; }
    }
}
