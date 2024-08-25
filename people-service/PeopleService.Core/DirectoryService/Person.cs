using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PeopleService.Core.DirectoryService
{
    public class Person
    {
        public required string LogonId { get; set; }
        public required string FullName{ get; set; }
        public required string Email { get; set; }
        public required string EmployeeId { get; set; }
        public required string Department { get; set; }
        public required string? PhotoUrl { get; set; }
    }
}
