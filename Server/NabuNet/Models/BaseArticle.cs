using System;

namespace NabuNet.Models
{
    public class BaseArticle
    {
        public DateTime Created { get; set; }
        public string Title { get; set; }

        public string Article { get; set; }

        public DateTime? ReferenceDate { get; set; }
    }
}