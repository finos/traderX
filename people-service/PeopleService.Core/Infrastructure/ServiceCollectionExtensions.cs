using CacheManager.Core;
using FluentValidation;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PeopleService.Core.DirectoryService;
using PeopleService.Core.Queries;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace PeopleService.Core.Infrastructure
{
    public static class ServiceCollectionExtensions
    {
        public static IServiceCollection AddPeopleServiceCore(this IServiceCollection serviceCollection, IConfigurationSection configurationSection)
        {
            return serviceCollection
                .AddMediatR(cfg => cfg.RegisterServicesFromAssemblies(Assembly.GetExecutingAssembly()))
                .AddValidatorsFromAssembly(Assembly.GetExecutingAssembly())
                .AddSingleton(ConfigureDirectoryService(configurationSection))
                .AddCacheManager<GetMatchingPeople.Response>(
                    c => c.WithDictionaryHandle()
                        .WithExpiration(ExpirationMode.Sliding, TimeSpan.FromMinutes(1)));

        }

        private static IDirectoryService ConfigureDirectoryService(IConfigurationSection configurationSection)
        {
            string filePath = configurationSection.Value;

            try
            {
                List<Person>? people = JsonFileReader.ReadJsonFile(filePath);
                return new DirectoryService.DirectoryService(people!);
            }
            catch (FileNotFoundException)
            {
                throw new Exception($"File not found: {filePath}");
            }
            catch (DirectoryNotFoundException)
            {
                throw new Exception($"Directory not found: {Path.GetDirectoryName(filePath)}");
            }
            catch (JsonException ex)
            {
                throw new Exception($"Error parsing JSON file: {ex.Message}");
            }
        }
    }
}
