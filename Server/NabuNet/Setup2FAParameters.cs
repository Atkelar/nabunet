namespace NabuNet
{
    public class Setup2FAParameters
    {
        public string QRCode { get; set; }
        public string UserName { get; set; }
        public string OTPUrl { get; internal set; }
    }
}