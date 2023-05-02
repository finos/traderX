using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PeopleService.Core.DirectoryService
{
    public class Person
    {
        public string LogonId { get; set; }
        public string FullName{ get; set; }
        public string Email { get; set; }
        public string EmployeeId { get; set; }
        public string Department { get; set; }
        public string PhotoUrl { get; set; }
    }
}
