using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Xml;
using System.Web;

namespace AsaParser {
	public class AccessList {
        public string Name;
        public string Type;
        public List<AccessListRule> Rules;
    }
}