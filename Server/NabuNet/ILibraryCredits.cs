using System.Collections.Generic;
using System.Threading.Tasks;

namespace NabuNet
{
    public interface ILibraryCredits
    {
        Task<IEnumerable<LibraryInfo>> GetLirbaryInfoAsync();
        public string Category { get; }
    }
}