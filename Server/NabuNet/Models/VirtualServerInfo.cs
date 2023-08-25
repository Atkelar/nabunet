namespace NabuNet
{
    public class VirtualServerInfo
        : IKeyRecord
    {
        public int Code { get; set; }
        public string Name { get; set; }
        public string Owner { get; set; }

        public bool IsActive { get; set; }
        public string? Id { get; set; }

        public string DeriveNewKey()
        {
            if (Code < 0 || Code > 0xFFFF)
                throw new System.InvalidOperationException("CODE invalid!");
            return Code.ToString("X4");
        }
    }
}