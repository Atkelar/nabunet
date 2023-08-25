namespace NabuNet
{
    public interface IKeyRecord
    {
        string? Id { get; set; }

        string DeriveNewKey();
    }
}