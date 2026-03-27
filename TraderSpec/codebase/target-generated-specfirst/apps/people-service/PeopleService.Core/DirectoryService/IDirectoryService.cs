using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PeopleService.Core.DirectoryService
{
    public interface IDirectoryService
    {
        Task<Person?> GetPerson(string logonId, string employeeId);
        Task<IEnumerable<Person>?> GetMatchingPerson(string searchText, int take);
        Task<bool> ValidatePerson(string logonId, string employeeId);
    }
}
