namespace PeopleService.Core.DirectoryService
{
    internal class DirectoryService : IDirectoryService
    {
        private readonly List<Person> _people;

        public DirectoryService(List<Person> people)
        {
            _people = people;
        }

        public Task<IEnumerable<Person>?> GetMatchingPerson(string searchText, int take)
        {
            return Task.FromResult(_people.Where(p => p.FullName.Contains(searchText) || p.LogonId.Contains(searchText))?.Take(take));
        }

        public Task<Person?> GetPerson(string logonId, string employeeId)
        {
            if (!string.IsNullOrEmpty(logonId))
            {
                return Task.FromResult(_people.FirstOrDefault(p => p.LogonId == logonId));
            }

            return Task.FromResult(_people.FirstOrDefault(p => p.EmployeeId == employeeId));
        }

        public async Task<bool> ValidatePerson(string logonId, string employeeId)
        {
            return await GetPerson(logonId, employeeId) != null;
        }
    }
}
