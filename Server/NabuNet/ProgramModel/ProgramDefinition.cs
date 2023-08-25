namespace NabuNet.ProgramModel
{
    public class ProgramDefinition
    {
        public string Title { get; set; }
        public string Version { get; set; }
        public string Author { get; set; }
        public string KernelType { get; set; }

        public int KernelVersionMin { get; set; }
        public int? KernelVersionMax { get; set; }

        public int Asset { get; set; }
    }
}