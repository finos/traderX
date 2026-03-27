using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace PeopleService.Core.DirectoryService
{
    public class JsonFileReader
    {
        public static List<Person>? ReadJsonFile(string path)
        {
            string jsonContent = File.ReadAllText(path);
            List<Person>? people = JsonSerializer.Deserialize<List<Person>>(jsonContent);
            return people;
        }
    }
}
