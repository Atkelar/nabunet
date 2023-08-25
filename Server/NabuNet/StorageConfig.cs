namespace NabuNet
{
    public class StorageConfig
    {
        public string BaseFolder { get; set; }
        public string DatabaseLocation { get; set; } = "db";
        public string BinariesLocation { get; set; } = "content";
        public string DatabaseName { get; set; } = "nabunet";
        public string MailTemplateFolder { get; set; } = "mailtpl";
        public string VServerFolder { get; set; } = "vservers";
    }
}