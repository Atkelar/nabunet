using System;

namespace NabuNet
{
    public abstract class DatabaseItem
    {
        public int? Id { get; set; }
        public DateTime Created { get; set; } = DateTime.UtcNow;
    }
}