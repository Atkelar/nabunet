namespace NabuNet
{
    public class MailConfig
    {
        public string SenderName { get; set; }
        public string SenderAddress { get; set; }
        public string Server { get; set; }
        public int Port { get; set; }
        public string? User { get; set; }
        public string? Password { get; set; }
    }
}