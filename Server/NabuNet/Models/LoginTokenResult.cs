using System;

namespace NabuNet
{
    public class LoginTokenResult
    {
        public string Token { get; set; }
        public DateTime ValidUntil { get; set; }
    }
}