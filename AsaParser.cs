using System;
using System.Xml;
using System.Web;
using System.Security.Cryptography.X509Certificates;
using System.Net;
using System.Net.Security;
using System.IO;
using System.Collections.Generic;
namespace AsaParser {
	public class Object {
        public string Name;
        public string Description;
        public string Type;
        public List<string> Value;
        public bool IsGroup;
    }
}
