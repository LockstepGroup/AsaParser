using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Xml;
using System.Web;

namespace AsaParser {
	public class Object {
        public string Name;
        public string Description;
        public string Type;
        public List<string> Value;
        public bool IsGroup;
    }
}